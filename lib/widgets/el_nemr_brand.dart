import 'package:flutter/material.dart';

class ElNemrLogo extends StatelessWidget {
  const ElNemrLogo({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF24D6FF),
            scheme.primary,
            const Color(0xFFFF4FD8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(-size * 0.045, 0),
            child: Icon(
              Icons.play_arrow_rounded,
              size: size * 0.68,
              color: Colors.white,
            ),
          ),
          Positioned(
            right: size * 0.08,
            bottom: size * 0.08,
            child: Container(
              width: size * 0.27,
              height: size * 0.27,
              decoration: BoxDecoration(
                color: const Color(0xFF07111F),
                borderRadius: BorderRadius.circular(size),
                border: Border.all(color: Colors.white70, width: 1),
              ),
              child: Icon(
                Icons.translate_rounded,
                size: size * 0.16,
                color: const Color(0xFF63E6FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ElNemrBrandLockup extends StatelessWidget {
  const ElNemrBrandLockup({
    super.key,
    this.compact = false,
    this.centered = false,
  });

  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        ElNemrLogo(size: compact ? 34 : 48),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                'El-Nemr Language',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
              Text(
                'Learn from every scene',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF63E6FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return content;
  }
}
