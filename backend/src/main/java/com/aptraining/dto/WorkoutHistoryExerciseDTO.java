package com.aptraining.dto;

import com.aptraining.entity.enums.MeasurementUnitEnum;
import com.aptraining.entity.enums.RepetitionType;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class WorkoutHistoryExerciseDTO {

    private UUID exerciseId;
    private String exerciseName;
    private Integer orderIndex;
    private Integer series;
    private Integer repetitions;
    private Integer repetitionsMax;
    private RepetitionType repetitionType;
    private Integer rpe;
    private MeasurementUnitEnum measurementUnit;
    private BigDecimal load;
    private List<WorkoutHistorySetDTO> sets = new ArrayList<>();
}