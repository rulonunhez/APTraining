package com.aptraining.catalogs.controller;

import com.aptraining.catalogs.ExerciseType;
import com.aptraining.catalogs.service.ExerciseTypeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/exercise-types")
@RequiredArgsConstructor
public class ExerciseTypeController {

    private final ExerciseTypeService exerciseTypeService;

    @GetMapping
    public ResponseEntity<List<ExerciseType>> getAll(Authentication authentication) {
        return ResponseEntity.ok(
                exerciseTypeService.getAll(authentication.getName())
        );
    }

}
