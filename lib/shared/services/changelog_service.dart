import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/changelog_entry.dart';

class ChangelogService {
  Future<List<ChangelogEntry>> loadChangelog() async {
    final String jsonString = await rootBundle.loadString('assets/changelog.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    final List<dynamic> versionsJson = jsonData['versions'];
    return versionsJson.map((v) => ChangelogEntry.fromJson(v)).toList();
  }
}