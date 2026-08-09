import 'package:flutter/material.dart';
import 'package:smart_medreminder/app/app.dart';
import 'package:smart_medreminder/core/services/medication_reminder_service.dart';
import 'package:smart_medreminder/features/medications/medication_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MedicationReminderService.instance.initialize();

  try {
    final existingMedications = await MedicationStorage.load();
    await MedicationReminderService.instance.rescheduleAll(existingMedications);
  } catch (_) {
    // Startup loading is considered tolerant. The UI will surface storage errors.
  }

  runApp(const SmartMedReminderApp());
}
