package com.aptraining.dto;

import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class TrainingPlanWorkoutDTO {

    private UUID trainingId;
    private String trainingName;
    private Integer orderIndex;
    private List<TrainingPlanScheduleDTO> schedules = new ArrayList<>();
    private List<TrainingPlanDateDTO> dates = new ArrayList<>();
}