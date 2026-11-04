import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ap_training/features/auth/providers/auth_provider.dart';

import '../data/training_remote_data_source.dart';
import '../models/training.dart';
import '../repositories/training_repository.dart';

final trainingRemoteDataSourceProvider = Provider<TrainingRemoteDataSource>(
  (ref) => TrainingRemoteDataSource(ref.watch(apiClientProvider)),
);

final trainingRepositoryProvider = Provider<TrainingRepository>(
  (ref) =>
      RemoteTrainingRepository(ref.watch(trainingRemoteDataSourceProvider)),
);

final trainingsProvider =
    AsyncNotifierProvider<TrainingsNotifier, List<Training>>(
  TrainingsNotifier.new,
);

class TrainingsNotifier extends AsyncNotifier<List<Training>> {
  @override
  Future<List<Training>> build() {
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
    return ref.watch(trainingRepositoryProvider).getTrainings();
  }

  Future<Training> getTraining(String id) =>
      ref.read(trainingRepositoryProvider).getTraining(id);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(trainingRepositoryProvider).getTrainings(),
    );
  }

  Future<Training> createTraining(Training training) async {
    final created =
        await ref.read(trainingRepositoryProvider).createTraining(training);
    await refresh();
    return created;
  }

  Future<Training> updateTraining(String id, Training training) async {
    final updated =
        await ref.read(trainingRepositoryProvider).updateTraining(id, training);
    await refresh();
    return updated;
  }

  Future<void> deleteTraining(String id) async {
    await ref.read(trainingRepositoryProvider).deleteTraining(id);
    state = state.whenData(
      (trainings) => trainings.where((training) => training.id != id).toList(),
    );
  }
}
