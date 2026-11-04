package com.aptraining.repository;

import com.aptraining.entity.TrainingExercise;
import com.aptraining.entity.TrainingExerciseId;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface TrainingExerciseRepository extends JpaRepository<TrainingExercise, TrainingExerciseId> {

    Optional<TrainingExercise> findFirstByExercise_Id(UUID exerciseId);
}