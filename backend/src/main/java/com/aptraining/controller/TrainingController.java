package com.aptraining.controller;

import com.aptraining.dto.TrainingDTO;
import com.aptraining.service.TrainingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/trainings")
@RequiredArgsConstructor
public class TrainingController {

    private final TrainingService trainingService;

    @PostMapping
    public ResponseEntity<?> create(
            @RequestBody TrainingDTO dto,
            Authentication auth
    ) {
        return ResponseEntity.ok(
                trainingService.create(dto, auth.getName())
        );
    }

    @GetMapping
    public ResponseEntity<?> getAll(Authentication auth) {
        return ResponseEntity.ok(
                trainingService.getAll(auth.getName())
        );
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getById(
            @PathVariable UUID id,
            Authentication auth
    ) {
        return ResponseEntity.ok(
                trainingService.getById(id, auth.getName())
        );
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(
            @PathVariable UUID id,
            @RequestBody TrainingDTO dto,
            Authentication auth
    ) {
        return ResponseEntity.ok(
                trainingService.update(id, dto, auth.getName())
        );
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(
            @PathVariable UUID id,
            Authentication auth
    ) {
        trainingService.delete(id, auth.getName());
        return ResponseEntity.ok().build();
    }

}
