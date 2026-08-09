import 'package:flutter/material.dart';
import 'package:smart_medreminder/app/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart MedReminder'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.medication_rounded,
                size: 80,
              ),

              const SizedBox(height: 24),

              const Text(
                'Welcome to Smart MedReminder',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              const Text(
                'Your medication dashboard',
                style: TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.addMedication,
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Medication'),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.medications,
                    );
                  },
                  icon: const Icon(Icons.medication),
                  label: const Text('My Medications'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
