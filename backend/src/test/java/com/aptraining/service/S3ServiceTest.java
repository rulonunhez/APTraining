package com.aptraining.service;

import com.aptraining.config.AwsProperties;
import com.aptraining.config.StorageOperationException;
import org.junit.jupiter.api.Test;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.io.IOException;

import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class S3ServiceTest {

    @Test
    void uploadWrapsFileReadFailureWithCauseForGlobalDiagnostics() throws Exception {
        MultipartFile file = mock(MultipartFile.class);
        when(file.getOriginalFilename()).thenReturn("exercise.mp4");
        when(file.getInputStream()).thenThrow(new IOException("disk read failed"));

        S3Service service = new S3Service(
                mock(S3Client.class),
                mock(S3Presigner.class),
                new AwsProperties()
        );

        StorageOperationException exception = assertThrows(
                StorageOperationException.class,
                () -> service.uploadFile(file)
        );

        assertInstanceOf(IOException.class, exception.getCause());
    }
}
