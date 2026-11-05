package com.aptraining.service;

import com.aptraining.dto.ProfileImageUploadUrlDTO;
import com.aptraining.dto.UserDTO;
import com.aptraining.entity.User;
import com.aptraining.repository.UserRepository;
import com.aptraining.requests.ProfileImageUploadUrlRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Duration;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class UserServiceTest {

    private static final String EMAIL = "ana@example.com";

    private UserRepository userRepository;
    private S3Service s3Service;
    private UserService userService;
    private User user;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        s3Service = mock(S3Service.class);
        userService = new UserService(userRepository, mock(PasswordEncoder.class), s3Service);

        user = new User();
        user.setId(UUID.randomUUID());
        user.setUsername("ana-gym");
        user.setEmail(EMAIL);
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test
    void uploadUrlRejectsNonImageContentType() {
        ProfileImageUploadUrlRequest request = new ProfileImageUploadUrlRequest("video/mp4", 1024L);

        assertThrows(IllegalArgumentException.class,
                () -> userService.createProfileImageUploadUrl(request, EMAIL));
    }

    @Test
    void uploadUrlRejectsOversizedImage() {
        ProfileImageUploadUrlRequest request =
                new ProfileImageUploadUrlRequest("image/png", 6L * 1024 * 1024);

        assertThrows(IllegalArgumentException.class,
                () -> userService.createProfileImageUploadUrl(request, EMAIL));
    }

    @Test
    void uploadUrlUsesAvatarPrefixOfTheUser() {
        when(s3Service.generateUploadUrl(any(), eq("image/jpeg"), eq(1024L)))
                .thenReturn("https://s3.example.com/upload");
        ProfileImageUploadUrlRequest request = new ProfileImageUploadUrlRequest("image/jpeg", 1024L);

        ProfileImageUploadUrlDTO result = userService.createProfileImageUploadUrl(request, EMAIL);

        assertTrue(result.getKey().startsWith(S3Service.userAvatarKeyPrefix(user.getId())));
        assertEquals("https://s3.example.com/upload", result.getUploadUrl());
        assertEquals("image/jpeg", result.getContentType());
    }

    @Test
    void updateRejectsKeyOutsideUserPrefix() {
        String foreignKey = S3Service.userAvatarKeyPrefix(UUID.randomUUID()) + UUID.randomUUID();

        assertThrows(IllegalArgumentException.class,
                () -> userService.updateProfileImage(foreignKey, EMAIL));
    }

    @Test
    void updateRejectsMissingObject() {
        String key = S3Service.userAvatarKeyPrefix(user.getId()) + UUID.randomUUID();
        when(s3Service.fileExists(key)).thenReturn(false);

        assertThrows(IllegalArgumentException.class,
                () -> userService.updateProfileImage(key, EMAIL));
    }

    @Test
    void updateStoresKeyAndDeletesPreviousAvatar() {
        String previousKey = S3Service.userAvatarKeyPrefix(user.getId()) + UUID.randomUUID();
        user.setProfileImageKey(previousKey);
        String newKey = S3Service.userAvatarKeyPrefix(user.getId()) + UUID.randomUUID();
        when(s3Service.fileExists(newKey)).thenReturn(true);
        when(s3Service.generatePresignedUrl(eq(newKey), eq(Duration.ofHours(12))))
                .thenReturn("https://s3.example.com/avatar");

        UserDTO result = userService.updateProfileImage(newKey, EMAIL);

        assertEquals(newKey, user.getProfileImageKey());
        assertEquals("https://s3.example.com/avatar", result.getProfileImageUrl());
        verify(s3Service).deleteFile(previousKey);
    }

    @Test
    void deleteClearsKeyAndRemovesFile() {
        String previousKey = S3Service.userAvatarKeyPrefix(user.getId()) + UUID.randomUUID();
        user.setProfileImageKey(previousKey);

        UserDTO result = userService.deleteProfileImage(EMAIL);

        assertNull(user.getProfileImageKey());
        assertNull(result.getProfileImageUrl());
        verify(s3Service).deleteFile(previousKey);
    }

    @Test
    void deleteWithoutAvatarDoesNotTouchStorage() {
        UserDTO result = userService.deleteProfileImage(EMAIL);

        assertNull(result.getProfileImageUrl());
        verify(s3Service, never()).deleteFile(any());
    }
}
