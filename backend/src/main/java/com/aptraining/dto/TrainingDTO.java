package com.aptraining.dto;

import lombok.Getter;
import lombok.Setter;

import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class TrainingDTO {

    private UUID id;
    private String name;
    private String description;
    private List<TrainingExerciseDTO> exercises;
    // Lectura: false cuando el entreno se ve por estar en un plan asignado
    private Boolean createdByMe;

    public TrainingDTO() {
    }

    public TrainingDTO(UUID id, String name) {
        this.id = id;
        this.name = name;
    }
}
