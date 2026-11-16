import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/player_controller.dart';
import '../theme/design.dart';

/// Первый запуск: пользователь должен (1) выдать разрешение кнопкой
/// и (2) принять условия — только тогда попадёт в приложение.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _accepted = false;
  bool _granted = false;
  bool _requesting = false;

  static const _rulesUrl = 'https://shubka.page.gd/pleer/pravila.html';

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    try {
      final ctrl = context.read<PlayerController>();
      final ok = await ctrl.library.ensurePermission();
      if (!mounted) return;
      setState(() => _granted = ok);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Доступ не предоставлен. Нажмите «Разрешить доступ» ещё раз.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _requesting = false);
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  bool get _canContinue => _accepted && _granted;

  Future<void> _openRules() async {
    try {
      await launchUrl(Uri.parse(_rulesUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
                const Spacer(),
                ClipRRect(
                  borderRadius: PleerDesign.brLg,
                  child: Image.asset(
                    'assets/backgrounds/pleer_ico.png',
                    height: 120,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.music_note,
                        size: 110,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Добро пожаловать в Pleer!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Музыка, видео и запись в одном приложении',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: PleerDesign.brLg,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _granted
                                ? Icons.check_circle
                                : Icons.perm_media_outlined,
                            color: _granted ? const Color(0xFF7CFFB2) : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _granted
                                  ? 'Доступ к медиатеке разрешён'
                                  : 'Разрешите доступ к медиатеке',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pleer покажет ваши песни и видео из памяти устройства.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed:
                            (_granted || _requesting) ? null : _requestPermission,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF5716FF),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: _requesting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_granted ? 'Разрешено ✓' : 'Разрешить доступ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Согласие с условиями
                InkWell(
                  borderRadius: PleerDesign.brSm,
                  onTap: () => setState(() => _accepted = !_accepted),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _accepted
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            children: [
                              Text('Я принимаю ',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9))),
                              GestureDetector(
                                onTap: _openRules,
                                child: const Text(
                                  'Условия пользования и Политику конфиденциальности',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canContinue
                        ? () async {
                            await context.read<PlayerController>().acceptOnboarding();
                            widget.onDone();
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
                      foregroundColor: const Color(0xFF5716FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Продолжить',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _canContinue
                      ? ''
                      : 'Разрешите доступ и примите условия, чтобы продолжить',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
    );
  }
}