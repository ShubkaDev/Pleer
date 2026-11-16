import 'package:flutter/material.dart';

import '../services/background_service.dart';

/// Экран выбора фона приложения: градиент по умолчанию или одна из 5 картинок.
class BackgroundScreen extends StatefulWidget {
  const BackgroundScreen({super.key});

  @override
  State<BackgroundScreen> createState() => _BackgroundScreenState();
}

class _BackgroundScreenState extends State<BackgroundScreen> {
  @override
  Widget build(BuildContext context) {
    final bg = BackgroundService.instance;
    final selected = bg.selected;

    return Scaffold(
      appBar: AppBar(title: const Text('Фон приложения')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _option(
            context,
            label: 'Градиент (по умолчанию)',
            value: null,
            selected: selected == null,
            preview: Container(
              decoration: const BoxDecoration(
                gradient: BackgroundService.defaultGradient,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final asset in BackgroundService.bgAssets)
                GestureDetector(
                  onTap: () async {
                    await bg.setBackground(asset);
                    if (mounted) setState(() {});
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(asset, fit: BoxFit.cover),
                      ),
                      if (selected == asset)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.check_circle,
                                color: Colors.white, size: 32),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required String label,
    required String? value,
    required bool selected,
    required Widget preview,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await BackgroundService.instance.setBackground(value);
        if (mounted) setState(() {});
      },
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 110, child: preview),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}