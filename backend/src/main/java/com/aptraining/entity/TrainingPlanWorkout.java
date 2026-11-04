package com.aptraining.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@Entity
@Table(name = "training_plan_workouts")
public class TrainingPlanWorkout {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "plan_id", nullable = false)
    private TrainingPlan plan;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "training_id", nullable = false)
    private Training training;

    @Column(name = "order_index", nullable = false)
    private Integer orderIndex;

    @OneToMany(mappedBy = "planWorkout", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("dayOfWeek ASC")
    private List<TrainingPlanSchedule> schedules = new ArrayList<>();

    @OneToMany(mappedBy = "planWorkout", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("scheduledDate ASC")
    private List<TrainingPlanWorkoutDate> dates = new ArrayList<>();
}