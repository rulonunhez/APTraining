package com.aptraining.repository;

import com.aptraining.entity.TrainingPlanWorkout;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface TrainingPlanWorkoutRepository extends JpaRepository<TrainingPlanWorkout, UUID> {

    Optional<TrainingPlanWorkout> findFirstByTraining_Id(UUID trainingId);
}