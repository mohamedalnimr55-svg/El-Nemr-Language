import 'package:flutter/material.dart';
import '../models/subtitle_layer.dart';

class MultiSubtitleOverlay extends StatelessWidget {
  const MultiSubtitleOverlay({
    super.key,
    required this.layers,
    required this.position,
    required this.editMode,
    required this.onChanged,
    this.safePadding = const EdgeInsets.all(16),
  });

  final List<SubtitleLayer> layers;
  final Duration position;
  final bool editMode;
  final ValueChanged<SubtitleLayer> onChanged;
  final EdgeInsets safePadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) return const SizedBox.shrink();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final layer in layers)
              if (layer.visible && layer.textAt(position).trim().isNotEmpty)
                _SubtitleLayerView(
                  key: ValueKey(layer.id),
                  layer: layer,
                  text: layer.textAt(position),
                  editMode: editMode,
                  bounds: Size(width, height),
                  safePadding: safePadding,
                  onChanged: onChanged,
                ),
          ],
        );
      },
    );
  }
}

class _SubtitleLayerView extends StatefulWidget {
  const _SubtitleLayerView({
    super.key,
    required this.layer,
    required this.text,
    required this.editMode,
    required this.bounds,
    required this.safePadding,
    required this.onChanged,
  });

  final SubtitleLayer layer;
  final String text;
  final bool editMode;
  final Size bounds;
  final EdgeInsets safePadding;
  final ValueChanged<SubtitleLayer> onChanged;

  @override
  State<_SubtitleLayerView> createState() => _SubtitleLayerViewState();
}

class _SubtitleLayerViewState extends State<_SubtitleLayerView> {
  double? _scaleStart;

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final maxWidth = (widget.bounds.width - widget.safePadding.horizontal).clamp(80.0, double.infinity).toDouble();
    final x = (layer.x * widget.bounds.width).clamp(widget.safePadding.left, widget.bounds.width - widget.safePadding.right).toDouble();
    final y = (layer.y * widget.bounds.height).clamp(widget.safePadding.top, widget.bounds.height - widget.safePadding.bottom).toDouble();

    final content = Container(
      constraints: BoxConstraints(maxWidth: maxWidth * 0.92),
      padding: EdgeInsets.symmetric(
        horizontal: widget.editMode ? 10 : 7,
        vertical: widget.editMode ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: layer.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: widget.editMode
            ? Border.all(color: layer.locked ? Colors.amberAccent : Colors.lightBlueAccent, width: 1.2)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: layer.textColor,
                fontSize: 22 * layer.scale,
                height: 1.25,
                fontWeight: FontWeight.w600,
                shadows: layer.outline
                    ? const [
                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(-1, -1)),
                      ]
                    : null,
              ),
            ),
          ),
          if (widget.editMode) ...[
            const SizedBox(width: 6),
            Icon(layer.locked ? Icons.lock : Icons.drag_indicator, color: Colors.white70, size: 18),
          ],
        ],
      ),
    );

    return Positioned(
      left: x,
      top: y,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onScaleStart: !widget.editMode || layer.locked
              ? null
              : (_) => _scaleStart = layer.scale,
          onScaleUpdate: !widget.editMode || layer.locked
              ? null
              : (details) {
                  if (details.pointerCount >= 2) {
                    layer.scale = ((_scaleStart ?? layer.scale) * details.scale).clamp(0.55, 2.8).toDouble();
                  } else {
                    layer.x = (layer.x + details.focalPointDelta.dx / widget.bounds.width).clamp(0.02, 0.98).toDouble();
                    layer.y = (layer.y + details.focalPointDelta.dy / widget.bounds.height).clamp(0.04, 0.96).toDouble();
                  }
                  widget.onChanged(layer);
                },
          onDoubleTap: !widget.editMode || layer.locked
              ? null
              : () {
                  layer.x = 0.5;
                  layer.y = layer.role == SubtitleLayerRole.translation ? 0.90 : 0.80;
                  layer.scale = 1.0;
                  widget.onChanged(layer);
                },
          child: content,
        ),
      ),
    );
  }
}
