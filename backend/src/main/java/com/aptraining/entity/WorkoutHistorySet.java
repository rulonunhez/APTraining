package com.aptraining.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name = "workout_history_sets")
public class WorkoutHistorySet {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "workout_history_exercise_id", nullable = false)
    private WorkoutHistoryExercise workoutHistoryExercise;

    @Column(name = "set_number", nullable = false)
    private Integer setNumber;

    @Column(nullable = false)
    private Integer repetitions;

    @Column(precision = 10, scale = 2)
    private BigDecimal load;
}
