package com.aptraining.catalogs.repository;

import com.aptraining.catalogs.MovementPattern;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MovementPatternRepository extends JpaRepository<MovementPattern, Long> {
    Optional<MovementPattern> findByCode(String code);
}
