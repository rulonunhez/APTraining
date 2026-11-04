package com.aptraining.requests;

import lombok.Getter;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
public class ExerciseSearchRequest {
    private String name;
    private List<Long> exerciseTypeIds;
    private List<Long> movementPatternIds;
    private List<Long> primaryMuscleGroupIds;
    private List<Long> secondaryMuscleGroupIds;
    private List<Long> equipmentIds;
    private String explanation;
    private String tips;
    private String commonMistakes;
    private Boolean hasVideo;
}
