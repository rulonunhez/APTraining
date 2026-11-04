package com.aptraining.dto.lists;

import com.aptraining.dto.ExerciseDTO;
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
public class ExerciseListDTO {
    private UUID id;
    private String name;
    private boolean hasVideo;
    private List<ExerciseDTO.MuscleGroupRef> primaryMuscleGroups;
    private List<ExerciseDTO.MuscleGroupRef> secondaryMuscleGroups;
}
