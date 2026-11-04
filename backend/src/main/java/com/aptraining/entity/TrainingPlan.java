package com.aptraining.entity;

import com.aptraining.entity.enums.TrainingPlanMode;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@Entity
@Table(name = "training_plans")
public class TrainingPlan {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    private String name;

    @Column(name = "start_date")
    private LocalDate startDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "mode", nullable = false, length = 10)
    private TrainingPlanMode mode = TrainingPlanMode.WEEKLY;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_created_by", nullable = false)
    private User user;

    @OneToMany(mappedBy = "plan", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("orderIndex ASC")
    private List<TrainingPlanWorkout> workouts = new ArrayList<>();
}