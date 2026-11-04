import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ap_training/features/exercise/screens/exercise_editor_screen.dart';
import 'package:ap_training/shared/screens/splash_screen.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/exercise/screens/exercises_screen.dart';
import '../../features/planning/screens/planning_screen.dart';
import '../../features/planning/screens/training_plan_editor_screen.dart';
import '../../features/users/screens/group_editor_screen.dart';
import '../../features/users/screens/groups_screen.dart';
import '../../features/users/screens/manage_trainers_screen.dart';
import '../../features/workout/models/training.dart';
import '../../features/workout/models/workout_history_entry.dart';
import '../../features/workout/screens/training_editor_screen.dart';
import '../../features/workout/screens/workout_history_detail_screen.dart';
import '../../features/workout/screens/workout_history_screen.dart';
import '../../features/workout/screens/workout_mode_screen.dart';
import '../../features/workout/screens/workout_session_screen.dart';
import '../../features/workout/screens/workouts_screen.dart';
import '../../shared/screens/main_screen.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

String? authRedirect({
  required bool isLoading,
  required bool isLoggedIn,
  required String path,
}) {
  if (isLoading) return '/splash';

  final isPublicAuthRoute = path == '/login' || path == '/register';
  if (!isLoggedIn && !isPublicAuthRoute) return '/login';
  if (isLoggedIn && (isPublicAuthRoute || path == '/')) return '/planning';
  return null;
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: RouterNotifier(ref),
    redirect: (context, state) => authRedirect(
      isLoading: authState.isLoading,
      isLoggedIn: authState.isLoggedIn,
      path: state.uri.path,
    ),
    routes: [
      // 🔐 Rutas fuera del shell
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/planning',
                builder: (context, state) => const PlanningScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const TrainingPlanEditorScreen(),
                  ),
                  GoRoute(
                    path: ':planId/edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => TrainingPlanEditorScreen(
                      planId: state.pathParameters['planId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                builder: (context, state) => const WorkoutModeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workouts',
                builder: (context, state) => const WorkoutsScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const TrainingEditorScreen(),
                  ),
                  GoRoute(
                    path: ':trainingId/edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => TrainingEditorScreen(
                      trainingId: state.pathParameters['trainingId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exercises',
                builder: (context, state) => const ExercisesScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ExerciseEditorScreen(),
                  ),
                  GoRoute(
                    path: ':exerciseId/edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ExerciseEditorScreen(
                      exerciseId: state.pathParameters['exerciseId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'groups',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const GroupsScreen(),
                    routes: [
                      GoRoute(
                        path: 'create',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => const GroupEditorScreen(),
                      ),
                      GoRoute(
                        path: ':groupId/edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => GroupEditorScreen(
                          groupId: state.pathParameters['groupId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'manage-trainers',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ManageTrainersScreen(),
                  ),
                  GoRoute(
                    path: 'workout-history',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const WorkoutHistoryScreen(),
                    routes: [
                      GoRoute(
                        path: 'users',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            const WorkoutHistoryScreen(otherUsersMode: true),
                      ),
                      GoRoute(
                        path: 'detail',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            WorkoutHistoryDetailScreen(
                          entry: state.extra as WorkoutHistoryEntry,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/workout/session/:trainingId',
        builder: (context, state) => WorkoutSessionScreen(
          trainingId: state.pathParameters['trainingId']!,
          initialTraining:
              state.extra is Training ? state.extra as Training : null,
        ),
      ),
    ],
  );
});
