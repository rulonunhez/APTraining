package com.aptraining.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name = "workout_history")
public class WorkoutHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "training_id")
    private Training training;

    // Planificación que estaba siguiendo el usuario al registrar el entreno.
    // Prepara el acceso futuro del entrenador al historial de sus entrenados.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "training_plan_id")
    private TrainingPlan trainingPlan;

    @Column(name = "training_name", nullable = false)
    private String trainingName;

    @Column(name = "completed_at", nullable = false)
    private Instant completedAt;

    @OneToMany(mappedBy = "workoutHistory", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("orderIndex ASC")
    private List<WorkoutHistoryExercise> exercises = new ArrayList<>();
}