package com.aptraining.entity;

import com.fasterxml.jackson.annotation.JsonBackReference;
import com.aptraining.catalogs.Equipment;
import com.aptraining.catalogs.ExerciseType;
import com.aptraining.catalogs.MovementPattern;
import com.aptraining.catalogs.MuscleGroup;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@Entity
@Table(name = "exercises")
public class Exercise {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    private String name;

    private LocalDateTime createdAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_created_by")
    @JsonBackReference
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "video_id")
    private Video video;

    // =========================
    // NUEVAS RELACIONES
    // =========================

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "exercise_type_id")
    private ExerciseType exerciseType;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "movement_pattern_id")
    private MovementPattern movementPattern;

    @ManyToMany
    @JoinTable(
            name = "exercise_primary_muscle_groups",
            joinColumns = @JoinColumn(name = "exercise_id"),
            inverseJoinColumns = @JoinColumn(name = "muscle_group_id")
    )
    private Set<MuscleGroup> primaryMuscleGroups = new HashSet<>();

    @ManyToMany
    @JoinTable(
            name = "exercise_secondary_muscle_groups",
            joinColumns = @JoinColumn(name = "exercise_id"),
            inverseJoinColumns = @JoinColumn(name = "muscle_group_id")
    )
    private Set<MuscleGroup> secondaryMuscleGroups = new HashSet<>();

    @ManyToMany
    @JoinTable(
            name = "exercise_equipment",
            joinColumns = @JoinColumn(name = "exercise_id"),
            inverseJoinColumns = @JoinColumn(name = "equipment_id")
    )
    private Set<Equipment> equipment = new HashSet<>();

    private String explanation;

    private String tips;

    @Column(name = "common_mistakes")
    private String commonMistakes;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}
