package com.aptraining.auth.security;

import com.aptraining.auth.config.JwtProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtServiceTest {

    private JwtService jwtService;
    private UserDetails userDetails;

    @BeforeEach
    void setUp() {
        JwtProperties properties = new JwtProperties();
        properties.setSecret("VGhpc0lzQVRlc3RPbmx5U2VjcmV0S2V5Rm9ySFRUUzMyIQ==");
        jwtService = new JwtService(properties);
        userDetails = User.withUsername("user@example.com").password("unused").authorities("USER").build();
    }

    @Test
    void accessTokenIsAcceptedOnlyAsAccessToken() {
        String accessToken = jwtService.generateAccessToken(userDetails);

        assertTrue(jwtService.isTokenValid(accessToken, userDetails));
        assertFalse(jwtService.isRefreshTokenValid(accessToken, userDetails));
    }

    @Test
    void refreshTokenIsAcceptedOnlyForRefreshFlow() {
        String refreshToken = jwtService.generateRefreshToken(userDetails);

        assertFalse(jwtService.isTokenValid(refreshToken, userDetails));
        assertTrue(jwtService.isRefreshTokenValid(refreshToken, userDetails));
    }

    @Test
    void malformedTokenIsRejected() {
        assertFalse(jwtService.isTokenValid("not-a-jwt", userDetails));
        assertFalse(jwtService.isRefreshTokenValid("not-a-jwt", userDetails));
    }

    @Test
    void missingSigningKeyFailsFast() {
        JwtProperties properties = new JwtProperties();
        JwtService service = new JwtService(properties);

        assertThrows(IllegalStateException.class, service::validateSigningKey);
    }
}