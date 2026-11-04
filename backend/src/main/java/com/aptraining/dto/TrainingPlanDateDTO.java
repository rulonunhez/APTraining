package com.aptraining.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;
import java.time.LocalTime;

@Getter
@Setter
public class TrainingPlanDateDTO {

    private LocalDate date;
    private LocalTime startTime;
    private LocalTime endTime;
}
