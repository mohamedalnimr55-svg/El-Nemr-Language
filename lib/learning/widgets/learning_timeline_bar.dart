import 'package:flutter/material.dart';
import '../models/learning_models.dart';

class LearningTimelineBar extends StatelessWidget {
  const LearningTimelineBar({
    super.key,
    required this.segments,
    required this.duration,
    required this.position,
    required this.progress,
    required this.onSeek,
  });

  final List<LearningSegment> segments;
  final Duration duration;
  final Duration position;
  final Map<String, dynamic> progress;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty || duration <= Duration.zero) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        final width = box?.size.width ?? 0;
        if (width <= 0) return;
        final ratio = (details.localPosition.dx / width).clamp(0.0, 1.0).toDouble();
        onSeek(Duration(milliseconds: (duration.inMilliseconds * ratio).round()));
      },
      child: SizedBox(
        height: 14,
        width: double.infinity,
        child: CustomPaint(
          painter: _LearningTimelinePainter(
            segments: segments,
            duration: duration,
            position: position,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _LearningTimelinePainter extends CustomPainter {
  const _LearningTimelinePainter({
    required this.segments,
    required this.duration,
    required this.position,
    required this.progress,
  });

  final List<LearningSegment> segments;
  final Duration duration;
  final Duration position;
  final Map<String, dynamic> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Rect.fromLTWH(0, 5, size.width, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: .14),
    );
    final totalMs = duration.inMilliseconds.toDouble();
    if (totalMs <= 0) return;
    for (final s in segments) {
      final start = (s.start.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble() * size.width;
      final end = (s.end.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble() * size.width;
      if (end <= start) continue;
      final raw = progress[s.id];
      final p = raw is Map ? raw : const {};
      final best = (p['best'] as num?)?.toDouble();
      final color = best != null && best >= .85
          ? Colors.greenAccent
          : s.difficulty >= .72
              ? Colors.redAccent
              : s.difficulty >= .48
                  ? Colors.amberAccent
                  : Colors.lightBlueAccent;
      canvas.drawRect(Rect.fromLTWH(start, 4, (end - start).clamp(1.0, size.width).toDouble(), 6), Paint()..color = color.withValues(alpha: .72));
    }
    final px = (position.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble() * size.width;
    canvas.drawCircle(Offset(px, 7), 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _LearningTimelinePainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.duration != duration ||
      oldDelegate.segments != segments ||
      oldDelegate.progress != progress;
}
