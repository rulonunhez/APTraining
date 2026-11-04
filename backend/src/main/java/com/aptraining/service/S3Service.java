package com.aptraining.service;

import com.aptraining.config.AwsProperties;
import com.aptraining.config.StorageOperationException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;

import java.io.IOException;
import java.time.Duration;
import java.util.HashMap;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class S3Service {

    private static final Duration UPLOAD_URL_DURATION = Duration.ofMinutes(15);

    private final S3Client s3Client;
    private final S3Presigner s3Presigner;
    private final AwsProperties awsProperties;

    public HashMap<String, String> uploadFile(MultipartFile file) {
        String key = UUID.randomUUID() + "_" + file.getOriginalFilename();

        try {
            s3Client.putObject(
                    PutObjectRequest.builder()
                            .bucket(awsProperties.getBucket())
                            .key(key)
                            .contentType(file.getContentType())
                            .build(),
                    RequestBody.fromInputStream(file.getInputStream(), file.getSize())
            );
            HashMap<String, String> s3identifiers = new HashMap<>();
            s3identifiers.put("key", key);
            s3identifiers.put("url", getFileUrl(key));
            return s3identifiers;

        } catch (IOException e) {
            throw new StorageOperationException("Error uploading file to S3", e);
        }
    }

    public static String userVideoKeyPrefix(UUID userId) {
        return "exercises/" + userId + "/";
    }

    public String generateUploadUrl(String key, String contentType, long contentLength) {
        PutObjectRequest putObjectRequest = PutObjectRequest.builder()
                .bucket(awsProperties.getBucket())
                .key(key)
                .contentType(contentType)
                .contentLength(contentLength)
                .build();

        try {
            return s3Presigner.presignPutObject(
                    PutObjectPresignRequest.builder()
                            .signatureDuration(UPLOAD_URL_DURATION)
                            .putObjectRequest(putObjectRequest)
                            .build()
            ).url().toString();
        } catch (SdkException e) {
            throw new StorageOperationException("Error generating S3 upload URL", e);
        }
    }

    public boolean fileExists(String key) {
        try {
            s3Client.headObject(
                    HeadObjectRequest.builder()
                            .bucket(awsProperties.getBucket())
                            .key(key)
                            .build()
            );
            return true;
        } catch (NoSuchKeyException e) {
            return false;
        }
    }

    public void deleteFile(String key) {
        s3Client.deleteObject(
                DeleteObjectRequest.builder()
                        .bucket(awsProperties.getBucket())
                        .key(key)
                        .build()
        );
    }

    public String getFileUrl(String key) {
        return "https://" + awsProperties.getBucket()
                + ".s3."
                + awsProperties.getRegion()
                + ".amazonaws.com/" + key;
    }

    public String generatePresignedUrl(String key) {
        GetObjectRequest getObjectRequest = GetObjectRequest.builder()
                .bucket(awsProperties.getBucket())
                .key(key)
                .build();

        GetObjectPresignRequest presignRequest =
                GetObjectPresignRequest.builder()
                        .signatureDuration(Duration.ofMinutes(5)) // URL expira en 5 min
                        .getObjectRequest(getObjectRequest)
                        .build();

        PresignedGetObjectRequest presignedRequest =
                s3Presigner.presignGetObject(presignRequest);

        return presignedRequest.url().toString();
    }
}