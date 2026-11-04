package com.aptraining.requests;

import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class WorkoutHistorySearchRequest {
    private Instant from;
    private Instant to;
    private List<UUID> trainingIds;
    private List<UUID> exerciseIds;
    // Solo entrenadores y admin pueden consultar el historial de otro usuario
    private UUID userId;
}
