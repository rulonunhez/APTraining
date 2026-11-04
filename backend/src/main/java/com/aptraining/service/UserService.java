package com.aptraining.service;

import com.aptraining.auth.model.dto.UserDetailsDto;
import com.aptraining.auth.model.enums.Role;
import com.aptraining.dto.UserDTO;
import com.aptraining.entity.User;
import com.aptraining.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public List<UserDTO> getUsers() {
        return userRepository.findAll()
                .stream()
                .map(user -> new UserDTO(user.getId(), user.getUsername(), user.getEmail(), user.getRole()))
                .collect(Collectors.toList());
    }

    public UserDTO updateRole(UUID userId, Role newRole, String adminEmail) {
        if (newRole == Role.ADMIN) {
            throw new RuntimeException("El rol de administrador no se puede asignar desde la aplicación");
        }
        User user = getById(userId);
        if (user.getEmail().equals(adminEmail)) {
            throw new RuntimeException("No puedes cambiar tu propio rol");
        }
        user.setRole(newRole);
        User saved = userRepository.save(user);
        return new UserDTO(saved.getId(), saved.getUsername(), saved.getEmail(), saved.getRole());
    }

    public void register(UserDetailsDto dto) {
//        if (userRepository.findByUsername(dto.getUsername())) {
//            throw new RuntimeException("Usuario ya existe");
//        }

        User user = new User(dto);
        user.setPasswordHash(passwordEncoder.encode(dto.getPassword()));
        user.setRole(Role.USER);
        user.setCreatedAt(LocalDateTime.now());

        userRepository.save(user);
    }

    public User findByUsername(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    }

    public User findByEmail(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    }

    public User getById(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    }
}