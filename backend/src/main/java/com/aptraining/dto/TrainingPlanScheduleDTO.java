package com.aptraining.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.DayOfWeek;
import java.time.LocalTime;

@Getter
@Setter
public class TrainingPlanScheduleDTO {

    private DayOfWeek dayOfWeek;
    private LocalTime startTime;
    private LocalTime endTime;
}