package com.aptraining.catalogs.controller;

import com.aptraining.catalogs.MovementPattern;
import com.aptraining.catalogs.service.MovementPatternService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/movement-patterns")
@RequiredArgsConstructor
public class MovementPatternController {

    private final MovementPatternService movementPatternService;

    @GetMapping
    public ResponseEntity<List<MovementPattern>> getAll(Authentication authentication) {
        return ResponseEntity.ok(
                movementPatternService.getAll(authentication.getName())
        );
    }

}

