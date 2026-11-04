package com.aptraining.auth.service;

import com.aptraining.auth.model.entity.RefreshToken;
import com.aptraining.auth.repository.RefreshTokenRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class RefreshTokenServiceTest {

    private final RefreshTokenRepository repository = mock(RefreshTokenRepository.class);
    private final RefreshTokenService service = new RefreshTokenService(repository);

    @Test
    void registerPersistsOnlyTheTokenHash() throws Exception {
        String rawToken = "refresh-secret";
        UUID userId = UUID.randomUUID();

        service.register(rawToken, userId);

        ArgumentCaptor<RefreshToken> captor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(repository).save(captor.capture());
        assertNotEquals(rawToken, captor.getValue().getTokenHash());
        assertEquals(hash(rawToken), captor.getValue().getTokenHash());
        assertEquals(userId, captor.getValue().getUserId());
    }

    @Test
    void lookupHashesThePresentedTokenBeforeQuerying() throws Exception {
        String rawToken = "presented-refresh-secret";
        when(repository.findByTokenHash(hash(rawToken))).thenReturn(Optional.empty());

        assertEquals(Optional.empty(), service.findByToken(rawToken));
        verify(repository).findByTokenHash(hash(rawToken));
    }

    @Test
    void rotationReplacesStoredHashInsteadOfPersistingTheNewToken() throws Exception {
        String rawToken = "rotated-refresh-secret";
        RefreshToken storedToken = new RefreshToken();
        storedToken.setTokenHash("previous-hash");

        service.rotateToken(storedToken, rawToken);

        assertEquals(hash(rawToken), storedToken.getTokenHash());
        assertNotEquals(rawToken, storedToken.getTokenHash());
        assertTrue(storedToken.getExpiryDate().isAfter(Instant.now()));
    }

    private String hash(String token) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest(token.getBytes(StandardCharsets.UTF_8));
        return HexFormat.of().formatHex(digest);
    }
}