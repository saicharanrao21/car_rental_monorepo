import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'core/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Robust global error trapping to prevent silent blank screens
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[DriveGo FlutterError] ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[DriveGo PlatformDispatcher Error] $error');
    return true; // Handled
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: DDSColors.bgCanvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: DDSColors.errorRed, size: 48),
              const Gap(12),
              Text(
                'Something went wrong',
                style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const Gap(8),
              Text(
                'An unexpected rendering issue occurred. Please try navigating or restarting.',
                style: DDSTypography.bodyMedium.copyWith(color: DDSColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: CustomerApp()));
}

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Car Rental Customer',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      scrollBehavior: const AppScrollBehavior(),
      debugShowCheckedModeBanner: false,
    );
  }
}
