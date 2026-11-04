package com.aptraining.controller;

import com.aptraining.dto.TrainingPlanDTO;
import com.aptraining.service.TrainingPlanService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/training-plans")
@RequiredArgsConstructor
public class TrainingPlanController {

    private final TrainingPlanService trainingPlanService;

    @PostMapping
    public ResponseEntity<?> create(@RequestBody TrainingPlanDTO dto, Authentication auth) {
        return ResponseEntity.ok(trainingPlanService.create(dto, auth.getName()));
    }

    @GetMapping
    public ResponseEntity<?> getAll(Authentication auth) {
        return ResponseEntity.ok(trainingPlanService.getAll(auth.getName()));
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getById(@PathVariable UUID id, Authentication auth) {
        return ResponseEntity.ok(trainingPlanService.getById(id, auth.getName()));
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(
            @PathVariable UUID id,
            @RequestBody TrainingPlanDTO dto,
            Authentication auth
    ) {
        return ResponseEntity.ok(trainingPlanService.update(id, dto, auth.getName()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable UUID id, Authentication auth) {
        trainingPlanService.delete(id, auth.getName());
        return ResponseEntity.ok().build();
    }
}