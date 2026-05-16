import 'package:pusulafit/core/services/notification_service.dart';
import 'package:pusulafit/features/auth/providers/auth_provider.dart';
import 'package:pusulafit/features/nutrition/presentation/state/diet_provider.dart';
import 'package:pusulafit/features/tasks/controllers/daily_tasks_controller.dart';
import 'package:pusulafit/features/tracking/providers/tracking_provider.dart';
import 'package:pusulafit/features/weight/presentation/providers/weight_provider.dart';
import 'package:pusulafit/features/workout/providers/workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

Widget buildTestApp(
  Widget home, {
  List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => DietProvider()),
      ChangeNotifierProvider(create: (_) => WorkoutProvider()),
      ChangeNotifierProvider(create: (_) => WeightProvider()),
      ChangeNotifierProvider(create: (_) => TrackingProvider()),
      ChangeNotifierProvider(create: (_) => NotificationService()),
      ChangeNotifierProvider(create: (_) => DailyTasksController()),
      ...extraProviders,
    ],
    child: MaterialApp(home: home),
  );
}
