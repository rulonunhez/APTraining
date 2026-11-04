package com.aptraining.controller;

import com.aptraining.dto.UserDTO;
import com.aptraining.entity.User;
import com.aptraining.requests.UpdateUserRoleRequest;
import com.aptraining.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    @Autowired
    private final UserService userService;

    @GetMapping
    public List<UserDTO> getUsers() {
        return userService.getUsers();
    }

    @GetMapping("/me")
    public UserDTO getCurrentUser(Authentication authentication) {
        User user = userService.findByEmail(authentication.getName());
        return new UserDTO(user.getId(), user.getUsername(), user.getEmail(), user.getRole());
    }

    @PatchMapping("/{id}/role")
    public UserDTO updateRole(
            @PathVariable UUID id,
            @RequestBody UpdateUserRoleRequest request,
            Authentication authentication
    ) {
        if (request.getRole() == null) {
            throw new RuntimeException("El rol es obligatorio");
        }
        return userService.updateRole(id, request.getRole(), authentication.getName());
    }

}