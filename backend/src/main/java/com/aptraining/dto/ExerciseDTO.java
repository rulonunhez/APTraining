package com.aptraining.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ExerciseDTO {
    private UUID id;
    private String name;
    private boolean hasVideo;
    private String videoUrl;
    private String videoSource;

    private Long exerciseTypeId;
    private String exerciseTypeName;

    private Long movementPatternId;
    private String movementPatternName;

    // Para las colecciones, devolver objetos con id y name
    private List<MuscleGroupRef> primaryMuscleGroups;
    private List<MuscleGroupRef> secondaryMuscleGroups;
    private List<EquipmentRef> equipment;

    private String explanation;
    private String tips;
    private String commonMistakes;

    @Getter
    @AllArgsConstructor
    public static class MuscleGroupRef {
        private Long id;
        private String name;
    }

    @Getter
    @AllArgsConstructor
    public static class EquipmentRef {
        private Long id;
        private String name;
    }
}