import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Medication {
  final String id;
  final String name;
  final String dosage;
  final String reminderTime;
  final String frequency;
  final int notificationId;
  final int? quantity;
  final DateTime? createdAt;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.reminderTime,
    required this.frequency,
    required this.notificationId,
    this.quantity,
    this.createdAt,
  });

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? reminderTime,
    String? frequency,
    int? notificationId,
    int? quantity,
    DateTime? createdAt,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      reminderTime: reminderTime ?? this.reminderTime,
      frequency: frequency ?? this.frequency,
      notificationId: notificationId ?? this.notificationId,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'reminderTime': reminderTime,
        'frequency': frequency,
        'notificationId': notificationId,
        if (quantity != null) 'quantity': quantity,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  factory Medication.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final nameValue = json['name'];
    final safeId = idValue is String && idValue.isNotEmpty
        ? idValue
        : (nameValue is String && nameValue.isNotEmpty
            ? nameValue
            : DateTime.now().millisecondsSinceEpoch.toString());

    return Medication(
      id: safeId,
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      reminderTime: json['reminderTime'] ?? json['time'] ?? '08:00',
      frequency: json['frequency'] ?? 'Every day',
      notificationId: json['notificationId'] is int
          ? json['notificationId'] as int
          : (safeId.hashCode & 0x7fffffff),
      quantity: json['quantity'] is int ? json['quantity'] as int : null,
        createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

class MedicationStorage {
  static const String key = 'smart_medreminder_medications_v1';

  static Future<List<Medication>> load() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final data = prefs.getStringList(key) ?? [];

      return data
          .map((item) => Medication.fromJson(jsonDecode(item)))
          .toList();
    } catch (error) {
      throw Exception('Unable to load medications: $error');
    }
  }

  static Future<void> save(List<Medication> medications) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.setStringList(
        key,
        medications.map((m) => jsonEncode(m.toJson())).toList(),
      );
    } catch (error) {
      throw Exception('Unable to persist medications: $error');
    }
  }

  static Future<void> deleteMedication(String medicationId) async {
    final existing = await load();
    final updated = existing.where((m) => m.id != medicationId).toList();
    await save(updated);
  }
}
