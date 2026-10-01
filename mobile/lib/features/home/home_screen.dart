import 'package:flutter/material.dart';
import 'package:smart_medreminder/app/routes.dart';
import 'package:smart_medreminder/core/services/local_auth_service.dart';
import 'package:smart_medreminder/core/services/medication_reminder_service.dart';
import 'package:smart_medreminder/features/medications/dose_history.dart';
import 'package:smart_medreminder/features/medications/medication_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Medication> _medications = [];
  List<DoseOccurrence> _todayOccurrences = [];
  List<DoseRecord> _doseHistory = [];
  LocalUser? _user;
  final Set<String> _savingDoseKeys = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final medications = await MedicationStorage.load();
      final occurrences = _buildTodayOccurrences(medications, DateTime.now());
      final history = await DoseHistoryStorage.markPastAsMissed(occurrences);
      final user = await LocalAuthService.instance.currentUser();
      if (!mounted) return;
      setState(() {
        _medications = medications;
        _todayOccurrences = occurrences;
        _doseHistory = history;
        _user = user;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load medications.';
      });
    }
  }

  int _dosesFor(Medication medication) {
    switch (medication.frequency.toLowerCase()) {
      case 'twice a day':
        return 2;
      case 'three times a day':
        return 3;
      case 'weekly':
        return DateTime.now().weekday == DateTime.monday ? 1 : 0;
      default:
        return 1;
    }
  }

  List<DoseOccurrence> _buildTodayOccurrences(
    List<Medication> medications,
    DateTime now,
  ) {
    final date = DateTime(now.year, now.month, now.day);
    return medications.expand((medication) {
      final parts = medication.reminderTime.split(':');
      final hour = int.tryParse(parts.first) ?? 8;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final offsets = switch (medication.frequency.toLowerCase()) {
        'twice a day' => [0, 12],
        'three times a day' => [0, 8, 16],
        'weekly' => now.weekday == DateTime.monday ? [0] : <int>[],
        _ => [0],
      };

      return offsets.map(
        (offset) {
          final scheduledAt = DateTime(
            date.year,
            date.month,
            date.day,
            hour + offset,
            minute,
          );
          if (medication.createdAt != null &&
              scheduledAt.isBefore(medication.createdAt!)) {
            return null;
          }
          return DoseOccurrence(
            medicationId: medication.id,
            scheduledAt: scheduledAt,
          );
        },
      );
    }).whereType<DoseOccurrence>().toList();
  }

  int get _scheduledDoses => _todayOccurrences.length;

  int _countStatus(String status) => _doseHistory.where(
        (record) =>
            record.status == status &&
            _todayOccurrences.any((occurrence) => occurrence.key == record.key),
      ).length;

  int get _takenDoses => _countStatus('taken');
  int get _skippedDoses => _countStatus('skipped');
  int get _missedDoses => _countStatus('missed');

  double get _adherence => _scheduledDoses == 0 ? 0 : _takenDoses / _scheduledDoses;

  DoseRecord? _recordFor(DoseOccurrence occurrence) {
    for (final record in _doseHistory) {
      if (record.key == occurrence.key) return record;
    }
    return null;
  }

  Medication? _medicationFor(String medicationId) {
    for (final medication in _medications) {
      if (medication.id == medicationId) return medication;
    }
    return null;
  }

  List<DoseOccurrence> get _sortedOccurrences {
    final occurrences = [..._todayOccurrences];
    occurrences.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return occurrences;
  }

  List<DoseRecord> get _recentActivity {
    final records = _doseHistory.where(
      (record) => _medicationFor(record.medicationId) != null,
    ).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return records.take(5).toList();
  }

  Future<void> _setDoseStatus(DoseOccurrence occurrence, String status) async {
    if (!_savingDoseKeys.add(occurrence.key)) return;

    try {
      final saved = await DoseHistoryStorage.saveStatus(
        occurrence: occurrence,
        status: status,
      );
      if (saved && mounted) await _loadMedications();
    } finally {
      _savingDoseKeys.remove(occurrence.key);
    }
  }

  Medication? get _nextMedication {
    final now = TimeOfDay.now();
    final upcoming = _medications.where((medication) {
      final parts = medication.reminderTime.split(':');
      final hour = int.tryParse(parts.first) ?? 0;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return _dosesFor(medication) > 0 &&
          (hour > now.hour || (hour == now.hour && minute >= now.minute));
    }).toList()
      ..sort((a, b) => a.reminderTime.compareTo(b.reminderTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<void> _scheduleTestNotification() async {
    try {
      await MedicationReminderService.instance.scheduleTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification scheduled for 10 seconds.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to schedule test notification.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await LocalAuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
  }

  Future<void> _openAndRefresh(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) _loadMedications();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = _nextMedication;
    final lowStock = _medications.where((medication) {
      return medication.quantity != null && medication.quantity! <= 5;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _loadMedications,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadMedications,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    Text(
                      _user == null || _user!.name.isEmpty
                          ? 'Good morning'
                          : 'Good morning, ${_user!.name}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Here's your medication plan for today",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) _MessageCard(message: _error!),
                    _AdherenceCard(
                      scheduled: _scheduledDoses,
                      taken: _takenDoses,
                      skipped: _skippedDoses,
                      missed: _missedDoses,
                      adherence: _adherence,
                    ),
                    const SizedBox(height: 14),
                    _NextDoseCard(medication: next),
                    if (lowStock.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _LowStockCard(medications: lowStock),
                    ],
                    const SizedBox(height: 26),
                    _SectionHeading(
                      title: "Today's timeline",
                      trailing: '${_todayOccurrences.length} doses',
                    ),
                    const SizedBox(height: 10),
                    if (_todayOccurrences.isEmpty)
                      const _EmptySection(
                        icon: Icons.event_available_outlined,
                        message: 'No medication doses scheduled today.',
                      )
                    else
                      ..._sortedOccurrences.map(
                        (occurrence) => _TimelineDoseCard(
                          medication: _medicationFor(occurrence.medicationId)!,
                          occurrence: occurrence,
                          record: _recordFor(occurrence),
                          onStatus: _setDoseStatus,
                        ),
                      ),
                    const SizedBox(height: 22),
                    _SectionHeading(
                      title: 'Medication overview',
                      trailing: '${_medications.length} total',
                    ),
                    const SizedBox(height: 10),
                    if (_medications.isEmpty)
                      _EmptyMedicationsCard(
                        onAdd: () => _openAndRefresh(AppRoutes.addMedication),
                      )
                    else
                      ..._medications.map(
                        (medication) => _MedicationOverviewCard(
                          medication: medication,
                          occurrences: _todayOccurrences
                              .where((occurrence) => occurrence.medicationId == medication.id)
                              .toList(),
                          recordFor: _recordFor,
                        ),
                      ),
                    if (_recentActivity.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const _SectionHeading(title: 'Recent dose activity'),
                      const SizedBox(height: 10),
                      _RecentActivityCard(
                        records: _recentActivity,
                        medicationFor: _medicationFor,
                      ),
                    ],
                    const SizedBox(height: 22),
                    const _SectionHeading(title: 'Quick actions'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openAndRefresh(AppRoutes.addMedication),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add Medication'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openAndRefresh(AppRoutes.scanPrescription),
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: const Text('Scan Prescription'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openAndRefresh(AppRoutes.medications),
                      icon: const Icon(Icons.medication_outlined),
                      label: const Text('Open My Medications'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _scheduleTestNotification,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Test Notification (10 seconds)'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({
    required this.scheduled,
    required this.taken,
    required this.skipped,
    required this.missed,
    required this.adherence,
  });
  final int scheduled;
  final int taken;
  final int skipped;
  final int missed;
  final double adherence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: scheduled == 0 ? 0 : adherence,
                    strokeWidth: 8,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withAlpha(35),
                  ),
                  Text(
                    scheduled == 0 ? '—' : '${(adherence * 100).round()}%',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's adherence",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    scheduled == 0
                        ? 'No doses scheduled today'
                        : '$taken of $scheduled doses taken',
                  ),
                  const SizedBox(height: 5),
                  Text(
                    scheduled == 0
                        ? 'Add a medication to get started'
                        : '$skipped skipped • $missed missed',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextDoseCard extends StatelessWidget {
  const _NextDoseCard({required this.medication});
  final Medication? medication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: const Icon(Icons.schedule_rounded),
        ),
        title: const Text('Next upcoming medication'),
        subtitle: Text(
          medication == null
              ? 'Nothing else scheduled today'
              : '${medication!.name} • ${medication!.dosage}',
        ),
        trailing: medication == null
            ? null
            : Text(
                medication!.reminderTime,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (trailing != null)
          Text(trailing!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _TimelineDoseCard extends StatelessWidget {
  const _TimelineDoseCard({
    required this.medication,
    required this.occurrence,
    required this.record,
    required this.onStatus,
  });

  final Medication medication;
  final DoseOccurrence occurrence;
  final DoseRecord? record;
  final Future<void> Function(DoseOccurrence occurrence, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = record?.status;
    final statusLabel = switch (status) {
      'taken' => 'Taken',
      'skipped' => 'Skipped',
      'missed' => 'Missed',
      _ => 'Upcoming',
    };
    final statusColor = switch (status) {
      'taken' => theme.colorScheme.primary,
      'skipped' => theme.colorScheme.tertiary,
      'missed' => theme.colorScheme.error,
      _ => theme.colorScheme.secondary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 66,
              child: Text(
                TimeOfDay.fromDateTime(occurrence.scheduledAt).format(context),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(medication.dosage, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(Icons.circle, size: 10, color: statusColor),
                        label: Text(statusLabel),
                      ),
                      if (status == null || status == 'missed') ...[
                        TextButton(
                          onPressed: () => onStatus(occurrence, 'skipped'),
                          child: const Text('SKIP'),
                        ),
                        FilledButton(
                          onPressed: () => onStatus(occurrence, 'taken'),
                          child: const Text('TAKE'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationOverviewCard extends StatelessWidget {
  const _MedicationOverviewCard({
    required this.medication,
    required this.occurrences,
    required this.recordFor,
  });

  final Medication medication;
  final List<DoseOccurrence> occurrences;
  final DoseRecord? Function(DoseOccurrence occurrence) recordFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = occurrences
        .map(recordFor)
        .whereType<DoseRecord>()
        .map((record) => record.status)
        .toList();
    final todayStatus = statuses.isEmpty
        ? 'Upcoming'
        : statuses.contains('missed')
            ? 'Missed'
            : statuses.contains('skipped')
                ? 'Skipped'
                : statuses.every((status) => status == 'taken')
                    ? 'Taken'
                    : 'Upcoming';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.medication_rounded)),
        title: Text(medication.name),
        subtitle: Text(
          '${medication.dosage}  •  ${medication.frequency}\n'
          'Reminder: ${medication.reminderTime}'
          '${medication.quantity == null ? '' : '  •  Qty ${medication.quantity}'}',
        ),
        isThreeLine: true,
        trailing: Text(
          todayStatus,
          style: theme.textTheme.labelLarge?.copyWith(
            color: todayStatus == 'Taken'
                ? theme.colorScheme.primary
                : todayStatus == 'Missed'
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.records, required this.medicationFor});

  final List<DoseRecord> records;
  final Medication? Function(String medicationId) medicationFor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: records.map((record) {
          final medication = medicationFor(record.medicationId);
          final status = record.status[0].toUpperCase() + record.status.substring(1);
          return ListTile(
            dense: true,
            leading: Icon(
              record.status == 'taken'
                  ? Icons.check_circle_outline
                  : record.status == 'missed'
                      ? Icons.error_outline
                      : Icons.skip_next_outlined,
            ),
            title: Text(medication?.name ?? 'Medication'),
            subtitle: Text(_formatDateTime(context, record.scheduledAt)),
            trailing: Text(status),
          );
        }).toList(),
      ),
    );
  }

  String _formatDateTime(BuildContext context, DateTime value) {
    final date = '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}';
    final time = TimeOfDay.fromDateTime(value);
    return '$date • ${time.format(context)}';
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 14),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.medications});
  final List<Medication> medications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
        title: const Text('Low stock warning'),
        subtitle: Text(
          medications
              .map((medication) => '${medication.name} (${medication.quantity})')
              .join(', '),
        ),
      ),
    );
  }
}

class _EmptyMedicationsCard extends StatelessWidget {
  const _EmptyMedicationsCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.medication_outlined, size: 42),
            const SizedBox(height: 10),
            const Text('No medications yet'),
            const SizedBox(height: 4),
            const Text("Add your first medication to build today's plan."),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add medication'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(message),
      ),
    );
  }
}
