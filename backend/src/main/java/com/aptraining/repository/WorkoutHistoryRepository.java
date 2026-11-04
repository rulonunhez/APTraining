package com.aptraining.repository;

import com.aptraining.entity.WorkoutHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface WorkoutHistoryRepository extends JpaRepository<WorkoutHistory, UUID>,
        JpaSpecificationExecutor<WorkoutHistory> {

    List<WorkoutHistory> findByUserIdOrderByCompletedAtDesc(UUID userId);

    // Opciones de filtro derivadas del propio historial del usuario
    @Query("SELECT DISTINCT h.training.id, h.trainingName FROM WorkoutHistory h "
            + "WHERE h.user.id = :userId AND h.training IS NOT NULL")
    List<Object[]> findDistinctTrainingOptions(@Param("userId") UUID userId);

    @Query("SELECT DISTINCT e.exercise.id, e.exerciseName FROM WorkoutHistoryExercise e "
            + "WHERE e.workoutHistory.user.id = :userId AND e.exercise IS NOT NULL")
    List<Object[]> findDistinctExerciseOptions(@Param("userId") UUID userId);
}