package com.aptraining.repository;

import com.aptraining.entity.Exercise;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.List;
import java.util.UUID;

public interface ExerciseRepository extends JpaRepository<Exercise, UUID>, JpaSpecificationExecutor<Exercise> {

    List<Exercise> findByUserId(UUID userId);

}
