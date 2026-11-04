package com.aptraining.auth.service;

import com.aptraining.auth.model.entity.RefreshToken;
import com.aptraining.auth.repository.RefreshTokenRepository;
import com.aptraining.auth.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private final RefreshTokenRepository refreshTokenRepository;

    public void register(String token, UUID userId) {
        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setTokenHash(hashToken(token));
        refreshToken.setUserId(userId);
        refreshToken.setExpiryDate(Instant.now().plus(JwtService.REFRESH_TOKEN_TTL));
        refreshTokenRepository.save(refreshToken);
    }

    public Optional<RefreshToken> findByToken(String refreshToken) {
        return refreshTokenRepository.findByTokenHash(hashToken(refreshToken));
    }

    public void delete(RefreshToken storedToken) {
        refreshTokenRepository.delete(storedToken);
    }

    public void rotateToken(RefreshToken oldToken, String newToken) {
        oldToken.setTokenHash(hashToken(newToken));
        oldToken.setExpiryDate(Instant.now().plus(JwtService.REFRESH_TOKEN_TTL));
        refreshTokenRepository.save(oldToken);
    }

    private String hashToken(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is not available", exception);
        }
    }
}

