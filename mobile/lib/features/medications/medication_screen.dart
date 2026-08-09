import 'package:flutter/material.dart';
import 'package:smart_medreminder/app/routes.dart';
import 'package:smart_medreminder/core/services/medication_reminder_service.dart';
import 'package:smart_medreminder/features/medications/medication_model.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key, this.medication});

  final Medication? medication;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final dosageController = TextEditingController();

  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
  String frequency = 'Every day';
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.medication;
    if (existing != null) {
      nameController.text = existing.name;
      dosageController.text = existing.dosage;
      frequency = existing.frequency;

      final parts = existing.reminderTime.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts[1]) ?? 0;
        selectedTime = TimeOfDay(hour: hour, minute: minute);
      }
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void resetForm() {
    nameController.clear();
    dosageController.clear();
    selectedTime = const TimeOfDay(hour: 8, minute: 0);
    frequency = 'Every day';
  }

  Future<void> saveMedication() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final name = nameController.text.trim();
      final dosage = dosageController.text.trim();
      final reminderTime = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

      final existing = widget.medication;

      final toStore = Medication(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        dosage: dosage,
        reminderTime: reminderTime,
        frequency: frequency,
        notificationId: existing?.notificationId ?? DateTime.now().millisecondsSinceEpoch.hashCode,
      );

      final existingList = await MedicationStorage.load();
      List<Medication> updated;

      if (existing != null) {
        updated = existingList.map((m) {
          if (m.id == existing.id) {
            return toStore;
          }
          return m;
        }).toList();

        await MedicationReminderService.instance.cancelMedication(existing);
      } else {
        updated = [...existingList, toStore];
      }

      await MedicationStorage.save(updated);

      await MedicationReminderService.instance.scheduleMedication(toStore);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication saved successfully.'),
        ),
      );

      resetForm();

      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.medications);
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save medication: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medication == null ? 'Add Medication' : 'Edit Medication'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add Medication',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medication name',
                    hintText: 'e.g. Paracetamol',
                    prefixIcon: Icon(Icons.medication),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter medication name.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    hintText: 'e.g. 500 mg',
                    prefixIcon: Icon(Icons.scale),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter dosage.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                InkWell(
                  onTap: pickTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Reminder time',
                      prefixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      selectedTime.format(context),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    prefixIcon: Icon(Icons.repeat),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Every day',
                      child: Text('Every day'),
                    ),
                    DropdownMenuItem(
                      value: 'Twice a day',
                      child: Text('Twice a day'),
                    ),
                    DropdownMenuItem(
                      value: 'Three times a day',
                      child: Text('Three times a day'),
                    ),
                    DropdownMenuItem(
                      value: 'Weekly',
                      child: Text('Weekly'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        frequency = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 28),

                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: saving ? null : saveMedication,
                    icon: const Icon(Icons.save),
                    label: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Medication'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  List<Medication> medications = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadMedications();
  }

  Future<void> loadMedications() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await MedicationStorage.load();

      if (!mounted) return;

      setState(() {
        medications = result;
        loading = false;
      });
    } catch (caught) {
      if (!mounted) return;

      setState(() {
        error = caught.toString();
        loading = false;
      });
    }
  }

  Future<void> deleteMedication(Medication medication) async {
    try {
      await MedicationReminderService.instance.cancelMedication(medication);
      await MedicationStorage.deleteMedication(medication.id);

      final refreshed = await MedicationStorage.load();

      if (!mounted) return;

      setState(() {
        medications = refreshed;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication deleted.'),
        ),
      );
    } catch (caught) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete medication: $caught'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medications'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final refreshed = await Navigator.pushNamed(
            context,
            AppRoutes.addMedication,
          );

          if (refreshed == true) {
            await loadMedications();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 42),
                        const SizedBox(height: 12),
                        Text(error ?? 'Something went wrong'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: loadMedications,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : medications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.medication_outlined,
                              size: 70,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No medications yet',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add your first medication to get started.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final refreshed = await Navigator.pushNamed(
                                  context,
                                  AppRoutes.addMedication,
                                );
                                if (refreshed == true) {
                                  await loadMedications();
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Medication'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadMedications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: medications.length,
                        itemBuilder: (context, index) {
                          final medication = medications[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.medication),
                              ),
                              title: Text(
                                medication.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${medication.dosage}\n'
                                'Reminder: ${medication.reminderTime} • '
                                '${medication.frequency}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () async {
                                      final refreshed = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddMedicationScreen(
                                            medication: medication,
                                          ),
                                        ),
                                      );

                                      if (refreshed == true) {
                                        await loadMedications();
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => deleteMedication(medication),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

