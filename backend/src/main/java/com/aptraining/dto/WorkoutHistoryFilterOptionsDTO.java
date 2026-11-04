package com.aptraining.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class WorkoutHistoryFilterOptionsDTO {

    private List<Option> trainings = new ArrayList<>();
    private List<Option> exercises = new ArrayList<>();

    @Getter
    @Setter
    @AllArgsConstructor
    public static class Option {
        private UUID id;
        private String name;
    }
}
