package com.aptraining.controller;

import com.aptraining.dto.ExerciseDTO;
import com.aptraining.dto.VideoUploadUrlDTO;
import com.aptraining.requests.VideoUploadUrlRequest;
import com.aptraining.dto.lists.ExerciseListDTO;
import com.aptraining.requests.CreateExerciseRequest;
import com.aptraining.requests.ExerciseSearchRequest;
import com.aptraining.service.ExerciseService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/exercises")
@RequiredArgsConstructor
public class ExerciseController {

    private final ExerciseService exerciseService;

    @GetMapping
    public ResponseEntity<List<ExerciseListDTO>> getExercises(Authentication authentication) {
        return ResponseEntity.ok(
                exerciseService.getUserExercises(authentication.getName())
        );
    }

    @GetMapping("/search")
    public ResponseEntity<List<ExerciseListDTO>> searchExercises(
            @ModelAttribute ExerciseSearchRequest filters,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                exerciseService.searchUserExercises(filters, authentication.getName())
        );
    }

    @GetMapping("/{id}")
    public ResponseEntity<ExerciseDTO> getExercise(
            @PathVariable UUID id,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                exerciseService.getExerciseDetail(id, authentication.getName())
        );
    }

    @PutMapping("/{id}")
    public ResponseEntity<ExerciseDTO> update(
            @PathVariable UUID id,
            @RequestPart("data") CreateExerciseRequest request,
            @RequestPart(value = "file",required = false) MultipartFile file,
            Authentication authentication
    ) {

        String email = authentication.getName();

        return ResponseEntity.ok(
                exerciseService.updateExercise(id, request, file, email)
        );
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(
            @PathVariable UUID id,
            Authentication auth
    ) {
        exerciseService.delete(id, auth.getName());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/video-upload-url")
    public ResponseEntity<VideoUploadUrlDTO> createVideoUploadUrl(
            @RequestBody VideoUploadUrlRequest request,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                exerciseService.createVideoUploadUrl(request, authentication.getName())
        );
    }

    @PostMapping
    public ResponseEntity<ExerciseDTO> create(
            @RequestPart("data") CreateExerciseRequest request,
            @RequestPart (required = false) MultipartFile file,
            Authentication authentication
    ) {

        String email = authentication.getName();

        return ResponseEntity.ok(
                exerciseService.createExercise(request, file, email)
        );
    }
}