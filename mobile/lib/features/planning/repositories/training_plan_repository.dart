import '../data/training_plan_remote_data_source.dart';
import '../models/training_plan.dart';

abstract interface class TrainingPlanRepository {
  Future<List<TrainingPlan>> getTrainingPlans();
  Future<TrainingPlan> getTrainingPlan(String id);
  Future<TrainingPlan> createTrainingPlan(TrainingPlan plan);
  Future<TrainingPlan> updateTrainingPlan(String id, TrainingPlan plan);
  Future<void> deleteTrainingPlan(String id);
}

class RemoteTrainingPlanRepository implements TrainingPlanRepository {
  const RemoteTrainingPlanRepository(this.dataSource);

  final TrainingPlanRemoteDataSource dataSource;

  @override
  Future<List<TrainingPlan>> getTrainingPlans() =>
      dataSource.getTrainingPlans();

  @override
  Future<TrainingPlan> getTrainingPlan(String id) =>
      dataSource.getTrainingPlan(id);

  @override
  Future<TrainingPlan> createTrainingPlan(TrainingPlan plan) =>
      dataSource.createTrainingPlan(plan);

  @override
  Future<TrainingPlan> updateTrainingPlan(String id, TrainingPlan plan) =>
      dataSource.updateTrainingPlan(id, plan);

  @override
  Future<void> deleteTrainingPlan(String id) =>
      dataSource.deleteTrainingPlan(id);
}
