package com.aptraining.catalogs.service;

import com.aptraining.catalogs.Equipment;
import com.aptraining.catalogs.repository.EquipmentRepository;
import com.aptraining.entity.User;
import com.aptraining.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class EquipmentService {

    private final EquipmentRepository equipmentRepository;
    private final UserRepository userRepository;

    public List<Equipment> getAll (String email) {
        userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return equipmentRepository.findAll();
    }

}
