package com.aptraining.catalogs.repository;

import com.aptraining.catalogs.ExerciseType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface ExerciseTypeRepository extends JpaRepository<ExerciseType, Long> {
    Optional<ExerciseType> findByCode(String code);
}
