package com.aptraining.repository;

import com.aptraining.entity.TrainingPlan;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface TrainingPlanRepository extends JpaRepository<TrainingPlan, UUID> {

    List<TrainingPlan> findByUserIdOrderByStartDateAsc(UUID userId);
}