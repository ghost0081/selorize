import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceDataCache {
  static const _prefix = 'device_data_cache_';

  static Future<List<Map<String, dynamic>>> loadTable(String tableName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$tableName');
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];

      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (e) {
      debugPrint('Device cache load error [$tableName]: $e');
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> saveTable(
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$tableName', jsonEncode(rows));
    } catch (e) {
      debugPrint('Device cache save error [$tableName]: $e');
    }
  }
}
