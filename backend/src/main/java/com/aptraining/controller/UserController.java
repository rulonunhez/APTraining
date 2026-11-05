package com.aptraining.controller;

import com.aptraining.dto.ProfileImageUploadUrlDTO;
import com.aptraining.dto.UserDTO;
import com.aptraining.entity.User;
import com.aptraining.requests.ProfileImageUploadUrlRequest;
import com.aptraining.requests.UpdateProfileImageRequest;
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
        return userService.toDTO(user);
    }

    @PostMapping("/me/profile-image-upload-url")
    public ProfileImageUploadUrlDTO createProfileImageUploadUrl(
            @RequestBody ProfileImageUploadUrlRequest request,
            Authentication authentication
    ) {
        return userService.createProfileImageUploadUrl(request, authentication.getName());
    }

    @PatchMapping("/me/profile-image")
    public UserDTO updateProfileImage(
            @RequestBody UpdateProfileImageRequest request,
            Authentication authentication
    ) {
        return userService.updateProfileImage(request.getKey(), authentication.getName());
    }

    @DeleteMapping("/me/profile-image")
    public UserDTO deleteProfileImage(Authentication authentication) {
        return userService.deleteProfileImage(authentication.getName());
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