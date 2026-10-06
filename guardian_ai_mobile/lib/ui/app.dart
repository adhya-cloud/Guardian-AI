import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../services/device_bridge.dart';
import '../services/location_service.dart';
import '../services/permissions.dart';
import '../services/places_service.dart';
import '../state/safety_controller.dart';
import 'onboarding/onboarding_screen.dart';
import 'shell.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class GuardianApp extends StatelessWidget {
  const GuardianApp({
    super.key,
    required this.controller,
    required this.places,
    this.accelerometer,
  });

  final SafetyController controller;
  final PlacesService places;

  /// User-acceleration samples for shake-to-SOS (null disables it, e.g. tests).
  final Stream<(double, double, double)> Function()? accelerometer;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SafetyController>.value(value: controller),
        Provider<PlacesService>.value(value: places),
        Provider<LocationService>.value(value: controller.location),
        Provider<DeviceBridge>.value(value: controller.device),
        Provider<PermissionService>.value(value: controller.permissions),
      ],
      child: Selector<SafetyController, String>(
        selector: (_, c) => c.profile?.language ?? c.onboardingLanguage,
        builder: (context, language, _) => MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppStrings.of(context).t('appName'),
          locale: Locale(language),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: _RootGate(accelerometer: accelerometer),
        ),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate({this.accelerometer});
  final Stream<(double, double, double)> Function()? accelerometer;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SafetyController>();
    if (!c.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (c.profile == null) return const OnboardingScreen();
    return HomeShell(accelerometer: accelerometer);
  }
}
