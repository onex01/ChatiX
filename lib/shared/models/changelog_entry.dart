class ChangelogEntry {
  final String version;
  final int build;
  final String date;
  final List<String> changes;

  ChangelogEntry({
    required this.version,
    required this.build,
    required this.date,
    required this.changes,
  });

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) {
    return ChangelogEntry(
      version: json['version'] as String,
      build: json['build'] as int,
      date: json['date'] as String,
      changes: (json['changes'] as List<dynamic>).cast<String>(),
    );
  }
}