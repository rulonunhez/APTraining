package com.aptraining.auth.controller;

import com.aptraining.auth.security.JwtService;
import com.aptraining.auth.model.dto.UserDetailsDto;
import com.aptraining.auth.model.entity.RefreshToken;
import com.aptraining.auth.service.RefreshTokenService;
import com.aptraining.entity.User;
import com.aptraining.service.UserService;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class AuthControllerTest {

    @Test
    void successfulLoginReturnsBothTokensAndStoresTheRefreshSession() {
        String email = "user@example.com";
        UUID userId = UUID.randomUUID();
        AuthenticationManager authenticationManager = mock(AuthenticationManager.class);
        when(authenticationManager.authenticate(any(Authentication.class)))
                .thenReturn(mock(Authentication.class));
        UserDetails userDetails = mock(UserDetails.class);
        User user = mock(User.class);
        when(user.getId()).thenReturn(userId);
        when(user.buildUserDetails()).thenReturn(userDetails);
        UserService userService = mock(UserService.class);
        when(userService.findByEmail(email)).thenReturn(user);
        JwtService jwtService = mock(JwtService.class);
        when(jwtService.generateAccessToken(userDetails)).thenReturn("access-token");
        when(jwtService.generateRefreshToken(userDetails)).thenReturn("refresh-token");
        RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
        AuthController controller = new AuthController(
                authenticationManager,
                jwtService,
                refreshTokenService,
                userService
        );

        ResponseEntity<?> response = controller.login(
                new AuthRequest(email, "password"),
                mock(HttpServletResponse.class)
        );

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(
                Map.of("accessToken", "access-token", "refreshToken", "refresh-token"),
                response.getBody()
        );
        verify(refreshTokenService).register("refresh-token", userId);
    }

        @Test
        void registrationDelegatesTheSubmittedUserToTheService() {
                UserDetailsDto request = new UserDetailsDto();
                request.setUsername("ana-gym");
                request.setEmail("ana@example.com");
                request.setPassword("secure-password");
                UserService userService = mock(UserService.class);
                AuthController controller = new AuthController(
                                mock(AuthenticationManager.class),
                                mock(JwtService.class),
                                mock(RefreshTokenService.class),
                                userService
                );

                ResponseEntity<?> response = controller.register(request);

                assertEquals(HttpStatus.OK, response.getStatusCode());
                verify(userService).register(request);
        }

    @Test
    void invalidCredentialsReturnUnauthorized() {
        AuthenticationManager authenticationManager = mock(AuthenticationManager.class);
        when(authenticationManager.authenticate(any(Authentication.class)))
                .thenThrow(new BadCredentialsException("Invalid credentials"));
        AuthController controller = controller(authenticationManager);

        ResponseEntity<?> response = controller.login(
                new AuthRequest("user@example.com", "wrong-password"),
                mock(HttpServletResponse.class)
        );

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    void unexpectedLoginFailureIsNotReportedAsInvalidCredentials() {
        AuthenticationManager authenticationManager = mock(AuthenticationManager.class);
        when(authenticationManager.authenticate(any(Authentication.class)))
                .thenReturn(mock(Authentication.class));
        UserService userService = mock(UserService.class);
        when(userService.findByEmail("user@example.com"))
                .thenThrow(new IllegalStateException("Database unavailable"));
        AuthController controller = new AuthController(
                authenticationManager,
                mock(JwtService.class),
                mock(RefreshTokenService.class),
                userService
        );

        assertThrows(
                IllegalStateException.class,
                () -> controller.login(
                        new AuthRequest("user@example.com", "password"),
                        mock(HttpServletResponse.class)
                )
        );
    }

    @Test
    void refreshRejectsTokensNotPresentInTheSessionStore() {
        RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
        when(refreshTokenService.findByToken("unregistered-token"))
                .thenReturn(Optional.empty());
        AuthController controller = new AuthController(
                mock(AuthenticationManager.class),
                mock(JwtService.class),
                refreshTokenService,
                mock(UserService.class)
        );

        ResponseEntity<?> response = controller.refresh(Map.of("refreshToken", "unregistered-token"));

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

        @Test
        void refreshDeletesAndRejectsAnExpiredSession() {
                String rawToken = "expired-refresh-token";
                RefreshToken storedToken = new RefreshToken();
                storedToken.setExpiryDate(Instant.now().minusSeconds(1));
                RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
                when(refreshTokenService.findByToken(rawToken)).thenReturn(Optional.of(storedToken));
                AuthController controller = new AuthController(
                                mock(AuthenticationManager.class),
                                mock(JwtService.class),
                                refreshTokenService,
                                mock(UserService.class)
                );

                ResponseEntity<?> response = controller.refresh(Map.of("refreshToken", rawToken));

                assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
                verify(refreshTokenService).delete(storedToken);
        }

        @Test
        void refreshRejectsStoredTokenWithWrongPurpose() {
                String rawToken = "access-token-stored-as-refresh";
                UUID userId = UUID.randomUUID();
                RefreshToken storedToken = new RefreshToken();
                storedToken.setUserId(userId);
                storedToken.setExpiryDate(Instant.now().plusSeconds(60));
                RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
                when(refreshTokenService.findByToken(rawToken)).thenReturn(Optional.of(storedToken));
                User user = mock(User.class);
                UserDetails userDetails = mock(UserDetails.class);
                UserService userService = mock(UserService.class);
                when(userService.getById(userId)).thenReturn(user);
                when(user.buildUserDetails()).thenReturn(userDetails);
                JwtService jwtService = mock(JwtService.class);
                when(jwtService.isRefreshTokenValid(rawToken, userDetails)).thenReturn(false);
                AuthController controller = new AuthController(
                                mock(AuthenticationManager.class),
                                jwtService,
                                refreshTokenService,
                                userService
                );

                ResponseEntity<?> response = controller.refresh(Map.of("refreshToken", rawToken));

                assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
                verify(refreshTokenService).delete(storedToken);
        }

        @Test
        void refreshRotatesAValidStoredRefreshToken() {
                String rawToken = "valid-refresh-token";
                UUID userId = UUID.randomUUID();
                RefreshToken storedToken = new RefreshToken();
                storedToken.setUserId(userId);
                storedToken.setExpiryDate(Instant.now().plusSeconds(60));
                RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
                when(refreshTokenService.findByToken(rawToken)).thenReturn(Optional.of(storedToken));
                User user = mock(User.class);
                UserDetails userDetails = mock(UserDetails.class);
                UserService userService = mock(UserService.class);
                when(userService.getById(userId)).thenReturn(user);
                when(user.buildUserDetails()).thenReturn(userDetails);
                JwtService jwtService = mock(JwtService.class);
                when(jwtService.isRefreshTokenValid(rawToken, userDetails)).thenReturn(true);
                when(jwtService.generateAccessToken(userDetails)).thenReturn("new-access-token");
                when(jwtService.generateRefreshToken(userDetails)).thenReturn("new-refresh-token");
                AuthController controller = new AuthController(
                                mock(AuthenticationManager.class),
                                jwtService,
                                refreshTokenService,
                                userService
                );

                ResponseEntity<?> response = controller.refresh(Map.of("refreshToken", rawToken));

                assertEquals(HttpStatus.OK, response.getStatusCode());
                assertEquals(
                                Map.of("accessToken", "new-access-token", "refreshToken", "new-refresh-token"),
                                response.getBody()
                );
                verify(refreshTokenService).rotateToken(storedToken, "new-refresh-token");
        }

    @Test
    void logoutDoesNotTrustAUserIdFromTheRequest() {
        RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
        AuthController controller = new AuthController(
                mock(AuthenticationManager.class),
                mock(JwtService.class),
                refreshTokenService,
                mock(UserService.class)
        );

        ResponseEntity<Void> response = controller.logout(
                Map.of("userId", UUID.randomUUID().toString())
        );

        assertEquals(HttpStatus.NO_CONTENT, response.getStatusCode());
        verifyNoInteractions(refreshTokenService);
    }

    @Test
    void logoutDeletesOnlyAStoredValidRefreshToken() {
        String rawToken = "valid-refresh-token";
        UUID userId = UUID.randomUUID();
        RefreshToken storedToken = new RefreshToken();
        storedToken.setUserId(userId);
        storedToken.setExpiryDate(Instant.now().plusSeconds(60));
        RefreshTokenService refreshTokenService = mock(RefreshTokenService.class);
        when(refreshTokenService.findByToken(rawToken)).thenReturn(Optional.of(storedToken));
        User user = mock(User.class);
        UserDetails userDetails = mock(UserDetails.class);
        UserService userService = mock(UserService.class);
        when(userService.getById(userId)).thenReturn(user);
        when(user.buildUserDetails()).thenReturn(userDetails);
        JwtService jwtService = mock(JwtService.class);
        when(jwtService.isRefreshTokenValid(rawToken, userDetails)).thenReturn(true);
        AuthController controller = new AuthController(
                mock(AuthenticationManager.class),
                jwtService,
                refreshTokenService,
                userService
        );

        ResponseEntity<Void> response = controller.logout(Map.of("refreshToken", rawToken));

        assertEquals(HttpStatus.NO_CONTENT, response.getStatusCode());
        verify(refreshTokenService).delete(storedToken);
    }

    private AuthController controller(AuthenticationManager authenticationManager) {
        return new AuthController(
                authenticationManager,
                mock(JwtService.class),
                mock(RefreshTokenService.class),
                mock(UserService.class)
        );
    }
}