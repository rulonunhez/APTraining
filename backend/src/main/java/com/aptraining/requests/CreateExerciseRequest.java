package com.aptraining.requests;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CreateExerciseRequest {
    private String name;
    private Long exerciseTypeId;
    private Long movementPatternId;
    private List<Long> primaryMuscleGroupIds;
    private List<Long> secondaryMuscleGroupIds;
    private List<Long> equipmentIds;
    private String explanation;
    private String tips;
    private String commonMistakes;
    private String videoSource;
    private String youtubeUrl;
    private String uploadedVideoKey;
    private String uploadedVideoName;
}
