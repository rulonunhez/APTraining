package com.aptraining.service;

import com.aptraining.auth.model.dto.UserDetailsDto;
import com.aptraining.auth.model.enums.Role;
import com.aptraining.dto.ProfileImageUploadUrlDTO;
import com.aptraining.dto.UserDTO;
import com.aptraining.entity.User;
import com.aptraining.repository.UserRepository;
import com.aptraining.requests.ProfileImageUploadUrlRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class UserService {

    private static final long MAX_PROFILE_IMAGE_SIZE_BYTES = 5L * 1024 * 1024;
    private static final Set<String> ALLOWED_IMAGE_TYPES = Set.of(
            "image/jpeg", "image/png", "image/webp"
    );
    // Los avatares se muestran en listas y selectores: la URL prefirmada
    // dura 12 h y la app la cachea en disco.
    private static final Duration PROFILE_IMAGE_URL_DURATION = Duration.ofHours(12);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final S3Service s3Service;

    public List<UserDTO> getUsers() {
        return userRepository.findAll()
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public UserDTO toDTO(User user) {
        String profileImageUrl = user.getProfileImageKey() == null
                ? null
                : s3Service.generatePresignedUrl(user.getProfileImageKey(), PROFILE_IMAGE_URL_DURATION);
        return new UserDTO(user.getId(), user.getUsername(), user.getEmail(), user.getRole(), profileImageUrl);
    }

    public ProfileImageUploadUrlDTO createProfileImageUploadUrl(ProfileImageUploadUrlRequest request, String email) {
        User user = findByEmail(email);

        String contentType = request.getContentType();
        if (contentType == null
                || !ALLOWED_IMAGE_TYPES.contains(contentType.toLowerCase(Locale.ROOT))) {
            throw new IllegalArgumentException("La imagen debe ser JPEG, PNG o WebP");
        }
        Long size = request.getSizeBytes();
        if (size == null || size <= 0 || size > MAX_PROFILE_IMAGE_SIZE_BYTES) {
            throw new IllegalArgumentException("La imagen supera el tamaño máximo permitido (5 MB)");
        }

        String key = S3Service.userAvatarKeyPrefix(user.getId()) + UUID.randomUUID();
        return new ProfileImageUploadUrlDTO(
                s3Service.generateUploadUrl(key, contentType, size),
                key,
                contentType
        );
    }

    public UserDTO updateProfileImage(String key, String email) {
        if (key == null || key.isBlank()) {
            throw new IllegalArgumentException("La clave de la imagen es obligatoria");
        }
        User user = findByEmail(email);
        if (!key.startsWith(S3Service.userAvatarKeyPrefix(user.getId()))) {
            throw new IllegalArgumentException("La imagen no pertenece al usuario");
        }
        if (!s3Service.fileExists(key)) {
            throw new IllegalArgumentException("La imagen no se ha subido correctamente");
        }

        String previousKey = user.getProfileImageKey();
        user.setProfileImageKey(key);
        User saved = userRepository.save(user);
        if (previousKey != null && !previousKey.equals(key)) {
            s3Service.deleteFile(previousKey);
        }
        return toDTO(saved);
    }

    public UserDTO deleteProfileImage(String email) {
        User user = findByEmail(email);
        String previousKey = user.getProfileImageKey();
        if (previousKey == null) {
            return toDTO(user);
        }
        user.setProfileImageKey(null);
        User saved = userRepository.save(user);
        s3Service.deleteFile(previousKey);
        return toDTO(saved);
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
        return toDTO(saved);
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