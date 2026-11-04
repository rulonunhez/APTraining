package com.aptraining.entity;

import com.aptraining.entity.enums.MeasurementUnitEnum;
import com.aptraining.entity.enums.RepetitionType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name = "workout_history_exercises")
public class WorkoutHistoryExercise {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "workout_history_id", nullable = false)
    private WorkoutHistory workoutHistory;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "exercise_id")
    private Exercise exercise;

    @Column(name = "exercise_name", nullable = false)
    private String exerciseName;

    @Column(name = "order_index", nullable = false)
    private Integer orderIndex;

    @Column(nullable = false)
    private Integer series;

    // Copia de la plantilla: puede ser nulo si la plantilla no lo define.
    // Lo realizado se registra en las series (workout_history_sets).
    @Column
    private Integer repetitions;

    @Column(name = "repetitions_max")
    private Integer repetitionsMax;

    @Enumerated(EnumType.STRING)
    @Column(name = "repetition_type", nullable = false, length = 10)
    private RepetitionType repetitionType;

    @Column
    private Integer rpe;

    @Enumerated(EnumType.STRING)
    @Column(name = "measurement_unit", nullable = false, length = 20)
    private MeasurementUnitEnum measurementUnit;

    @Column(precision = 10, scale = 2)
    private BigDecimal load;

    @OneToMany(mappedBy = "workoutHistoryExercise", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("setNumber ASC")
    private List<WorkoutHistorySet> sets = new ArrayList<>();
}