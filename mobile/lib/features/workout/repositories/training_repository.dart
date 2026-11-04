import '../data/training_remote_data_source.dart';
import '../models/training.dart';

abstract interface class TrainingRepository {
  Future<List<Training>> getTrainings();
  Future<Training> getTraining(String id);
  Future<Training> createTraining(Training training);
  Future<Training> updateTraining(String id, Training training);
  Future<void> deleteTraining(String id);
}

class RemoteTrainingRepository implements TrainingRepository {
  const RemoteTrainingRepository(this.dataSource);

  final TrainingRemoteDataSource dataSource;

  @override
  Future<List<Training>> getTrainings() => dataSource.getTrainings();

  @override
  Future<Training> getTraining(String id) => dataSource.getTraining(id);

  @override
  Future<Training> createTraining(Training training) =>
      dataSource.createTraining(training);

  @override
  Future<Training> updateTraining(String id, Training training) =>
      dataSource.updateTraining(id, training);

  @override
  Future<void> deleteTraining(String id) => dataSource.deleteTraining(id);
}
