package com.aptraining.catalogs.repository;

import com.aptraining.catalogs.MuscleGroup;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MuscleGroupRepository extends JpaRepository<MuscleGroup, Long> {
    Optional<MuscleGroup> findByCode(String code);
}
