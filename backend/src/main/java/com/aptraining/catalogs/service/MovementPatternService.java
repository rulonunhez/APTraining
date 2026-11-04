package com.aptraining.catalogs.service;

import com.aptraining.catalogs.MovementPattern;
import com.aptraining.catalogs.repository.MovementPatternRepository;
import com.aptraining.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class MovementPatternService {

    private final MovementPatternRepository movementPatternRepository;
    private final UserRepository userRepository;

    public List<MovementPattern> getAll (String email) {
        userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return movementPatternRepository.findAll();
    }
}
