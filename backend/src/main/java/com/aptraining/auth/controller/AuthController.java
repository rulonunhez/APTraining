package com.aptraining.auth.controller;

import com.aptraining.auth.model.dto.UserDetailsDto;
import com.aptraining.auth.security.JwtService;
import com.aptraining.auth.model.entity.RefreshToken;
import com.aptraining.auth.service.RefreshTokenService;
import com.aptraining.entity.User;
import com.aptraining.service.UserService;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@RestController
@RequiredArgsConstructor
@RequestMapping("/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final UserService userService;

    @PostMapping("/login")
    public ResponseEntity<Map<String, String>> login(@RequestBody AuthRequest request, HttpServletResponse response) {
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.email(), request.password()));

            User user = userService.findByEmail(request.email());
            UserDetails userToGetToken = user.buildUserDetails();

            String accessToken = jwtService.generateAccessToken(userToGetToken);
            String refreshToken = jwtService.generateRefreshToken(userToGetToken);

            refreshTokenService.register(refreshToken, user.getId());

            // Devolvemos solo el accessToken
            Map<String, String> responseBody = new HashMap<>();
            responseBody.put("accessToken", accessToken);
            responseBody.put("refreshToken", refreshToken);
            return ResponseEntity.ok(responseBody);
        } catch (AuthenticationException e) {
            return new ResponseEntity<>(HttpStatus.UNAUTHORIZED);
        }
    }

    @PostMapping("/register")
    public ResponseEntity<String> register(@RequestBody UserDetailsDto userDetailsDto) {
        userService.register(userDetailsDto);
        return ResponseEntity.ok("Usuario registrado");
    }

    @PostMapping("/refresh")
    public ResponseEntity<Map<String, String>> refresh(@RequestBody Map<String, String> request) {

        String refreshToken = request.get("refreshToken");

        if (refreshToken == null || refreshToken.isBlank()) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Refresh Token requerido"));
        }

        Optional<RefreshToken> matchingToken = refreshTokenService.findByToken(refreshToken);
        if (matchingToken.isEmpty()) {
            return invalidRefreshToken();
        }
        RefreshToken storedToken = matchingToken.get();

        if (storedToken.isExpired()) {
            refreshTokenService.delete(storedToken);
            return invalidRefreshToken();
        }

        User user = userService.getById(storedToken.getUserId());
        UserDetails userToGetToken = user.buildUserDetails();
        if (!jwtService.isRefreshTokenValid(refreshToken, userToGetToken)) {
            refreshTokenService.delete(storedToken);
            return invalidRefreshToken();
        }

        String newAccessToken = jwtService.generateAccessToken(userToGetToken);
        String newRefreshToken = jwtService.generateRefreshToken(userToGetToken);

        refreshTokenService.rotateToken(storedToken, newRefreshToken);

        return ResponseEntity.ok(Map.of(
                "accessToken", newAccessToken,
                "refreshToken", newRefreshToken
        ));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@RequestBody(required = false) Map<String, String> request) {
        String refreshToken = request == null ? null : request.get("refreshToken");
        if (refreshToken != null && !refreshToken.isBlank()) {
            Optional<RefreshToken> matchingToken = refreshTokenService.findByToken(refreshToken);
            if (matchingToken.isPresent()) {
                RefreshToken storedToken = matchingToken.get();
                if (storedToken.isExpired()) {
                    refreshTokenService.delete(storedToken);
                } else {
                    User user = userService.getById(storedToken.getUserId());
                    if (jwtService.isRefreshTokenValid(refreshToken, user.buildUserDetails())) {
                        refreshTokenService.delete(storedToken);
                    }
                }
            }
        }
        return ResponseEntity.noContent().build();
    }

    private ResponseEntity<Map<String, String>> invalidRefreshToken() {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", "Refresh token no válido"));
    }

}