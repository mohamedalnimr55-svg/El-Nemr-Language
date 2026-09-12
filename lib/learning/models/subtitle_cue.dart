class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;

  bool contains(Duration position, {Duration delay = Duration.zero}) {
    final shifted = position - delay;
    return shifted >= start && shifted < end;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'text': text,
      };

  factory SubtitleCue.fromJson(Map<String, dynamic> json) => SubtitleCue(
        start: Duration(milliseconds: (json['startMs'] as num?)?.toInt() ?? 0),
        end: Duration(milliseconds: (json['endMs'] as num?)?.toInt() ?? 0),
        text: json['text'] as String? ?? '',
      );
}
