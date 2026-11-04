package com.aptraining.catalogs.controller;

import com.aptraining.catalogs.Equipment;
import com.aptraining.catalogs.service.EquipmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/equipment")
@RequiredArgsConstructor
public class EquipmentController {

    private final EquipmentService equipmentService;

    @GetMapping
    public ResponseEntity<List<Equipment>> getAll(Authentication authentication) {
        return ResponseEntity.ok(
                equipmentService.getAll(authentication.getName())
        );
    }

}
