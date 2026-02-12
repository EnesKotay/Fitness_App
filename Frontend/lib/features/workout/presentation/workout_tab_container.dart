import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/workout_catalog_provider.dart';
import 'pages/body_region_select_page.dart';
import 'pages/exercise_list_page.dart';
import 'pages/exercise_detail_page.dart';
import '../data/models/body_region.dart';
import '../data/models/exercise_catalog.dart';

/// Antrenman sekmesi: kendi Navigator'ı ile Bölge Seç → Hareket Listesi → Hareket Detay.
/// Alt navigasyon bar kaybolmadan sayfa geçişleri yapılır.
class WorkoutTabContainer extends StatelessWidget {
  const WorkoutTabContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      initialRoute: 'regions',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case 'regions':
            return MaterialPageRoute<void>(
              builder: (_) => const BodyRegionSelectPage(),
            );
          case 'workout/exercises':
            final region = settings.arguments as BodyRegion?;
            if (region == null) {
              return MaterialPageRoute<void>(
                builder: (_) => const BodyRegionSelectPage(),
              );
            }
            return MaterialPageRoute<void>(
              builder: (_) => ExerciseListPage(region: region),
            );
          case 'detail':
            final exercise = settings.arguments as ExerciseCatalog?;
            if (exercise == null) {
              return MaterialPageRoute<void>(
                builder: (_) => const BodyRegionSelectPage(),
              );
            }
            return MaterialPageRoute<void>(
              builder: (_) => ExerciseDetailPage(exercise: exercise),
            );
          default:
            return MaterialPageRoute<void>(
              builder: (_) => const BodyRegionSelectPage(),
            );
        }
      },
    );
  }
}
