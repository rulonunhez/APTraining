package com.aptraining.repository;

import com.aptraining.entity.TrainingPlanAssignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface TrainingPlanAssignmentRepository extends JpaRepository<TrainingPlanAssignment, UUID> {

    List<TrainingPlanAssignment> findByUserId(UUID userId);

    List<TrainingPlanAssignment> findByPlanId(UUID planId);

    List<TrainingPlanAssignment> findBySourceGroupId(UUID groupId);

    boolean existsByPlanIdAndUserId(UUID planId, UUID userId);

    @Query("select case when count(w) > 0 then true else false end "
            + "from TrainingPlanWorkout w "
            + "join TrainingPlanAssignment a on a.plan = w.plan "
            + "where w.training.id = :trainingId and a.user.id = :userId")
    boolean isTrainingAssignedToUser(@Param("trainingId") UUID trainingId, @Param("userId") UUID userId);

    @Query("select case when count(te) > 0 then true else false end "
            + "from TrainingExercise te "
            + "join TrainingPlanWorkout w on w.training = te.training "
            + "join TrainingPlanAssignment a on a.plan = w.plan "
            + "where te.exercise.id = :exerciseId and a.user.id = :userId")
    boolean isExerciseAssignedToUser(@Param("exerciseId") UUID exerciseId, @Param("userId") UUID userId);
}
