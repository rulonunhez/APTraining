package com.aptraining.dto;

import com.aptraining.entity.enums.MeasurementUnitEnum;
import com.aptraining.entity.enums.RepetitionType;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.UUID;

@Getter
@Setter
public class TrainingExerciseDTO {

    private UUID exerciseId;
    private String exerciseName;
    private boolean hasVideo;
    private Integer repetitions;
    private Integer repetitionsMax;
    private RepetitionType repetitionType;
    private Integer series;
    private Integer rpe;
    private MeasurementUnitEnum measurementUnit;
    private BigDecimal load;
    private Integer orderIndex;

    public TrainingExerciseDTO(UUID exerciseId, Integer repetitions, Integer repetitionsMax,
                               RepetitionType repetitionType, Integer series, Integer rpe,
                               MeasurementUnitEnum measurementUnit, BigDecimal load, Integer orderIndex) {
        this.exerciseId = exerciseId;
        this.repetitions = repetitions;
        this.repetitionsMax = repetitionsMax;
        this.repetitionType = repetitionType;
        this.series = series;
        this.rpe = rpe;
        this.measurementUnit = measurementUnit;
        this.load = load;
        this.orderIndex = orderIndex;
    }

    public TrainingExerciseDTO() {
    }
}
