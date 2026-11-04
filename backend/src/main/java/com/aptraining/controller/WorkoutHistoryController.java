package com.aptraining.controller;

import com.aptraining.dto.WorkoutHistoryDTO;
import com.aptraining.dto.WorkoutHistoryFilterOptionsDTO;
import com.aptraining.requests.WorkoutHistorySearchRequest;
import com.aptraining.service.WorkoutHistoryService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/workout-history")
@RequiredArgsConstructor
public class WorkoutHistoryController {

    private final WorkoutHistoryService workoutHistoryService;

    @GetMapping
    public ResponseEntity<List<WorkoutHistoryDTO>> getAll(Authentication auth) {
        return ResponseEntity.ok(workoutHistoryService.getAll(auth.getName()));
    }

    @GetMapping("/search")
    public ResponseEntity<List<WorkoutHistoryDTO>> search(
            @ModelAttribute WorkoutHistorySearchRequest filters,
            Authentication auth
    ) {
        return ResponseEntity.ok(workoutHistoryService.search(filters, auth.getName()));
    }

    @GetMapping("/filter-options")
    public ResponseEntity<WorkoutHistoryFilterOptionsDTO> getFilterOptions(
            @RequestParam(required = false) UUID userId,
            Authentication auth
    ) {
        return ResponseEntity.ok(workoutHistoryService.getFilterOptions(userId, auth.getName()));
    }

    @PostMapping
    public ResponseEntity<WorkoutHistoryDTO> create(
            @RequestBody WorkoutHistoryDTO dto,
            Authentication auth
    ) {
        return ResponseEntity.ok(workoutHistoryService.create(dto, auth.getName()));
    }
}