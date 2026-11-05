package com.aptraining.controller;

import com.aptraining.dto.UserDTO;
import com.aptraining.entity.User;
import com.aptraining.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class UserControllerTest {

    @Test
    void currentUserIsResolvedFromTheAuthenticatedEmail() {
        String email = "ana@example.com";
        UUID userId = UUID.randomUUID();
        Authentication authentication = mock(Authentication.class);
        when(authentication.getName()).thenReturn(email);
        User user = mock(User.class);
        UserService userService = mock(UserService.class);
        when(userService.findByEmail(email)).thenReturn(user);
        UserDTO dto = new UserDTO(userId, "ana-gym", email, null, "https://example.com/avatar.png");
        when(userService.toDTO(user)).thenReturn(dto);

        UserDTO result = new UserController(userService).getCurrentUser(authentication);

        assertEquals(userId, result.getId());
        assertEquals("ana-gym", result.getUsername());
        assertEquals(email, result.getEmail());
        assertEquals("https://example.com/avatar.png", result.getProfileImageUrl());
    }
}
