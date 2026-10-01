import 'package:flutter/material.dart';
import 'package:smart_medreminder/features/auth/login_screen.dart';
import 'package:smart_medreminder/features/auth/registration_screen.dart';
import 'package:smart_medreminder/features/home/home_screen.dart';
import 'package:smart_medreminder/features/medications/medication_screen.dart';
import 'package:smart_medreminder/features/scanner/prescription_scanner_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String addMedication = '/add-medication';
  static const String medications = '/medications';
  static const String scanPrescription = '/scan-prescription';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case register:
        return MaterialPageRoute(
          builder: (_) => const RegistrationScreen(),
          settings: settings,
        );

      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );

      case addMedication:
        return MaterialPageRoute(
          builder: (_) => const AddMedicationScreen(),
          settings: settings,
        );

      case medications:
        return MaterialPageRoute(
          builder: (_) => const MedicationListScreen(),
          settings: settings,
        );

      case scanPrescription:
        return MaterialPageRoute(
          builder: (_) => const PrescriptionScannerScreen(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Placeholder(),
          settings: settings,
        );
    }
  }
}
