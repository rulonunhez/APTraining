import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';

import '../data/training_plan_remote_data_source.dart';
import '../models/training_plan.dart';
import '../repositories/training_plan_repository.dart';

final trainingPlanRemoteDataSourceProvider =
    Provider<TrainingPlanRemoteDataSource>(
  (ref) => TrainingPlanRemoteDataSource(ref.watch(apiClientProvider)),
);

final trainingPlanRepositoryProvider = Provider<TrainingPlanRepository>(
  (ref) => RemoteTrainingPlanRepository(
    ref.watch(trainingPlanRemoteDataSourceProvider),
  ),
);

final trainingPlansProvider =
    AsyncNotifierProvider<TrainingPlansNotifier, List<TrainingPlan>>(
  TrainingPlansNotifier.new,
);

class TrainingPlansNotifier extends AsyncNotifier<List<TrainingPlan>> {
  @override
  Future<List<TrainingPlan>> build() {
    ref.listen(
      authProvider.select((authState) => authState.isLoggedIn),
      (wasLoggedIn, isLoggedIn) {
        if (isLoggedIn && wasLoggedIn != true) {
          refresh();
        } else if (!isLoggedIn) {
          state = const AsyncData([]);
        }
      },
    );
    return ref.watch(trainingPlanRepositoryProvider).getTrainingPlans();
  }

  Future<TrainingPlan> getTrainingPlan(String id) =>
      ref.read(trainingPlanRepositoryProvider).getTrainingPlan(id);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(trainingPlanRepositoryProvider).getTrainingPlans(),
    );
  }

  Future<TrainingPlan> createTrainingPlan(TrainingPlan plan) async {
    final created =
        await ref.read(trainingPlanRepositoryProvider).createTrainingPlan(plan);
    await refresh();
    return created;
  }

  Future<TrainingPlan> updateTrainingPlan(String id, TrainingPlan plan) async {
    final updated = await ref
        .read(trainingPlanRepositoryProvider)
        .updateTrainingPlan(id, plan);
    await refresh();
    return updated;
  }

  Future<void> deleteTrainingPlan(String id) async {
    await ref.read(trainingPlanRepositoryProvider).deleteTrainingPlan(id);
    state = state.whenData(
      (plans) => plans.where((plan) => plan.id != id).toList(),
    );
  }
}
