package com.aptraining.catalogs.controller;

import com.aptraining.catalogs.MuscleGroup;
import com.aptraining.catalogs.service.MuscleGroupService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/muscle-groups")
@RequiredArgsConstructor
public class MuscleGroupController {

    private final MuscleGroupService muscleGroupService;

    @GetMapping
    public ResponseEntity<List<MuscleGroup>> getAll(Authentication authentication) {
        return ResponseEntity.ok(
                muscleGroupService.getAll(authentication.getName())
        );
    }

}
