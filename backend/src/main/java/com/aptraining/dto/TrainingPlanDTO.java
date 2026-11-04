package com.aptraining.dto;

import com.aptraining.entity.enums.TrainingPlanMode;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class TrainingPlanDTO {

    private UUID id;
    private String name;
    private TrainingPlanMode mode;
    private LocalDate startDate;
    private LocalDate endDate;
    private List<TrainingPlanWorkoutDTO> workouts = new ArrayList<>();

    // Escritura (solo creador): usuarios individuales y grupos a asignar.
    // Los grupos se expanden a asignaciones individuales al guardar.
    private List<UUID> assignedUserIds = new ArrayList<>();
    private List<UUID> assignedGroupIds = new ArrayList<>();

    // Lectura
    private Boolean createdByMe;
    private String assignedByUsername;
    private List<UserDTO> assignedUsers = new ArrayList<>();
}