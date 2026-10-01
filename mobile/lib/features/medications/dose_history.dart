import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DoseRecord {
  const DoseRecord({
    required this.medicationId,
    required this.scheduledAt,
    required this.status,
    this.takenAt,
  });

  final String medicationId;
  final DateTime scheduledAt;
  final String status;
  final DateTime? takenAt;

  Map<String, dynamic> toJson() => {
        'medicationId': medicationId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'status': status,
        if (takenAt != null) 'takenAt': takenAt!.toIso8601String(),
      };

  factory DoseRecord.fromJson(Map<String, dynamic> json) {
    final scheduledAt = DateTime.tryParse(json['scheduledAt'] as String? ?? '');
    if (scheduledAt == null) {
      throw const FormatException('Invalid scheduled dose time.');
    }

    final status = json['status'] as String?;
    if (status != 'taken' && status != 'skipped' && status != 'missed') {
      throw const FormatException('Invalid dose status.');
    }

    final takenValue = json['takenAt'] as String?;
    return DoseRecord(
      medicationId: json['medicationId'] as String? ?? '',
      scheduledAt: scheduledAt,
      status: status!,
      takenAt: takenValue == null ? null : DateTime.tryParse(takenValue),
    );
  }

  String get key => '$medicationId|${scheduledAt.toIso8601String()}';
}

class DoseOccurrence {
  const DoseOccurrence({
    required this.medicationId,
    required this.scheduledAt,
  });

  final String medicationId;
  final DateTime scheduledAt;

  String get key => '$medicationId|${scheduledAt.toIso8601String()}';
}

class DoseHistoryStorage {
  DoseHistoryStorage._();

  static const String key = 'smart_medreminder_dose_history_v1';

  static Future<List<DoseRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];

    try {
      return data
          .map((item) => DoseRecord.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw Exception('Unable to load dose history: $error');
    }
  }

  static Future<bool> saveStatus({
    required DoseOccurrence occurrence,
    required String status,
  }) async {
    if (status != 'taken' && status != 'skipped' && status != 'missed') {
      throw ArgumentError.value(status, 'status');
    }

    final records = await load();
    final existingIndex = records.indexWhere((record) => record.key == occurrence.key);
    if (existingIndex >= 0 && records[existingIndex].status != 'missed') {
      return false;
    }

    final record = DoseRecord(
      medicationId: occurrence.medicationId,
      scheduledAt: occurrence.scheduledAt,
      status: status,
      takenAt: status == 'taken' ? DateTime.now() : null,
    );
    final updated = [...records];
    if (existingIndex >= 0) {
      updated[existingIndex] = record;
    } else {
      updated.add(record);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      key,
      updated.map((item) => jsonEncode(item.toJson())).toList(),
    );
    return true;
  }

  static Future<List<DoseRecord>> markPastAsMissed(
    List<DoseOccurrence> occurrences,
  ) async {
    final records = await load();
    final existingKeys = records.map((record) => record.key).toSet();
    final additions = occurrences
        .where(
          (occurrence) =>
              occurrence.scheduledAt.isBefore(DateTime.now()) &&
              !existingKeys.contains(occurrence.key),
        )
        .map(
          (occurrence) => DoseRecord(
            medicationId: occurrence.medicationId,
            scheduledAt: occurrence.scheduledAt,
            status: 'missed',
          ),
        )
        .toList();

    if (additions.isEmpty) return records;

    final updated = [...records, ...additions];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      key,
      updated.map((item) => jsonEncode(item.toJson())).toList(),
    );
    return updated;
  }
}
