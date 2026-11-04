package com.aptraining.entity;

import com.aptraining.entity.enums.MeasurementUnitEnum;
import com.aptraining.entity.enums.RepetitionType;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@Entity
@Table(name = "training_exercises")
public class TrainingExercise {

    @EmbeddedId
    private TrainingExerciseId id;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("trainingId")
    @JoinColumn(name = "training_id")
    private Training training;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("exerciseId")
    @JoinColumn(name = "exercise_id")
    private Exercise exercise;

    private Integer repetitions;

    @Column(name = "repetitions_max")
    private Integer repetitionsMax;

    @Enumerated(EnumType.STRING)
    @Column(name = "repetition_type", length = 10)
    private RepetitionType repetitionType;

    private Integer series;

    private Integer rpe;

    @Enumerated(EnumType.STRING)
    @Column(name = "measurement_unit", length = 20)
    private MeasurementUnitEnum measurementUnit;

    private BigDecimal load;

    @Column(name = "order_index")
    private Integer orderIndex;
}
