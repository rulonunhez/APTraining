package com.aptraining.catalogs.service;

import com.aptraining.catalogs.ExerciseType;
import com.aptraining.catalogs.repository.ExerciseTypeRepository;
import com.aptraining.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ExerciseTypeService {

    private final ExerciseTypeRepository exerciseTypeRepository;
    private final UserRepository userRepository;

    public List<ExerciseType> getAll (String email) {
        userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return exerciseTypeRepository.findAll();
    }
}
