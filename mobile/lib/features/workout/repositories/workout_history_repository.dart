import '../data/workout_history_remote_data_source.dart';
import '../models/workout_history_entry.dart';
import '../models/workout_history_filter.dart';

abstract interface class WorkoutHistoryRepository {
  Future<List<WorkoutHistoryEntry>> getWorkoutHistory();
  Future<WorkoutHistoryEntry> recordActivity(WorkoutHistoryEntry entry);
  Future<List<WorkoutHistoryEntry>> searchWorkoutHistory({
    DateTime? from,
    DateTime? to,
    List<String> trainingIds,
    List<String> exerciseIds,
    String? userId,
  });
  Future<WorkoutHistoryFilterOptions> getFilterOptions({String? userId});
}

class RemoteWorkoutHistoryRepository implements WorkoutHistoryRepository {
  const RemoteWorkoutHistoryRepository(this.dataSource);

  final WorkoutHistoryRemoteDataSource dataSource;

  @override
  Future<List<WorkoutHistoryEntry>> getWorkoutHistory() =>
      dataSource.getWorkoutHistory();

  @override
  Future<WorkoutHistoryEntry> recordActivity(WorkoutHistoryEntry entry) =>
      dataSource.recordActivity(entry);

  @override
  Future<List<WorkoutHistoryEntry>> searchWorkoutHistory({
    DateTime? from,
    DateTime? to,
    List<String> trainingIds = const [],
    List<String> exerciseIds = const [],
    String? userId,
  }) =>
      dataSource.searchWorkoutHistory(
        from: from,
        to: to,
        trainingIds: trainingIds,
        exerciseIds: exerciseIds,
        userId: userId,
      );

  @override
  Future<WorkoutHistoryFilterOptions> getFilterOptions({String? userId}) =>
      dataSource.getFilterOptions(userId: userId);
}
