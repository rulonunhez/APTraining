package com.aptraining.repository;

import com.aptraining.entity.Training;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TrainingRepository extends JpaRepository<Training, UUID> {

    List<Training> findByUserId(UUID userId);

        @Query("select distinct t from Training t " +
            "left join fetch t.exercises te " +
            "left join fetch te.exercise e " +
            "left join fetch e.video " +
            "where t.user.id = :userId")
        List<Training> findByUserIdWithExercisesAndVideos(@Param("userId") UUID userId);

        @Query("select distinct t from Training t " +
            "left join fetch t.exercises te " +
            "left join fetch te.exercise e " +
            "left join fetch e.video " +
            "where t.id = :trainingId")
        Optional<Training> findByIdWithExercisesAndVideos(@Param("trainingId") UUID trainingId);

        // Entrenos visibles por estar en un plan asignado al usuario
        @Query("select distinct t from Training t " +
            "left join fetch t.exercises te " +
            "left join fetch te.exercise e " +
            "left join fetch e.video " +
            "where t.id in (select w.training.id from TrainingPlanWorkout w " +
            "join TrainingPlanAssignment a on a.plan = w.plan " +
            "where a.user.id = :userId)")
        List<Training> findAssignedToUserWithExercisesAndVideos(@Param("userId") UUID userId);

}
