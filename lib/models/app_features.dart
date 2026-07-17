class AppFeatures {
  final bool map;
  final bool calendar;
  final bool messages;

  const AppFeatures({
    required this.map,
    required this.calendar,
    required this.messages,
  });

  static const allEnabled = AppFeatures(
    map: true,
    calendar: true,
    messages: true,
  );

  factory AppFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AppFeatures.allEnabled;
    return AppFeatures(
      map: _flag(json['map'], true),
      calendar: _flag(json['calendar'], true),
      messages: _flag(json['messages'], true),
    );
  }

  static bool _flag(Object? value, bool fallback) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return fallback;
      return !(normalized == '0' ||
          normalized == 'false' ||
          normalized == 'off' ||
          normalized == 'no');
    }
    return fallback;
  }
}
