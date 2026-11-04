package com.aptraining.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class WorkoutHistoryDTO {

    private UUID id;
    private UUID trainingId;
    private UUID trainingPlanId;
    private String trainingName;
    private Instant completedAt;
    private List<WorkoutHistoryExerciseDTO> exercises = new ArrayList<>();
}