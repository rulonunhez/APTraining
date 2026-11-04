package com.aptraining.catalogs.service;

import com.aptraining.catalogs.MuscleGroup;
import com.aptraining.catalogs.repository.MuscleGroupRepository;
import com.aptraining.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class MuscleGroupService {

    private final MuscleGroupRepository muscleGroupRepository;
    private final UserRepository userRepository;

    public List<MuscleGroup> getAll (String email) {
        userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return muscleGroupRepository.findAll();
    }
}
