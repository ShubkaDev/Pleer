import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../logic/player_controller.dart';

/// Обложка трека без «мерцания».
///
/// Обычный FutureBuilder создаёт новый Future на каждой перерисовке списка,
/// поэтому на один кадр картинка пропадала и иконки треков мигали. Здесь
/// байты запрашиваются один раз на состояние виджета (плюс кэш в
/// LibraryService), а пока они грузятся — показывается заглушка.
class TrackArt extends StatefulWidget {
  const TrackArt({super.key, required this.trackId, required this.builder});

  final int? trackId;
  final Widget Function(BuildContext context, Uint8List? art) builder;

  @override
  State<TrackArt> createState() => _TrackArtState();
}

class _TrackArtState extends State<TrackArt> {
  Uint8List? _art;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrackArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _art = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.trackId;
    if (id == null) return;
    try {
      final ctrl = PlayerController.ofContextSafe(context);
      final bytes = await ctrl?.library.albumArt(id);
      if (!mounted) return;
      setState(() => _art = (bytes != null && bytes.isEmpty) ? null : bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _art = null);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _art);
}
