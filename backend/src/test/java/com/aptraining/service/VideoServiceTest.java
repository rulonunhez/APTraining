package com.aptraining.service;

import com.aptraining.entity.Video;
import com.aptraining.repository.VideoRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VideoServiceTest {

    @Mock
    private VideoRepository videoRepository;

    @Mock
    private S3Service s3Service;

    @InjectMocks
    private VideoService videoService;

    @Test
    void getVideosReturnsPresignedUrlAndVideoDetails() {
        UUID videoId = UUID.randomUUID();
        Video video = new Video();
        video.setId(videoId);
        video.setTitle("Demo");
        video.setDescription("Video de demostración");
        video.setS3Key("demo-video-key");
        video.setS3Url("https://bucket.s3.amazonaws.com/demo-video-key");
        video.setDuration(42);
        when(videoRepository.findAll()).thenReturn(List.of(video));
        when(s3Service.generatePresignedUrl("demo-video-key"))
                .thenReturn("https://signed.example/demo-video-key");

        var result = videoService.getVideos();

        assertEquals(1, result.size());
        assertEquals(videoId, result.get(0).getId());
        assertEquals("Demo", result.get(0).getTitle());
        assertEquals("Video de demostración", result.get(0).getDescription());
        assertEquals("demo-video-key", result.get(0).getKey());
        assertEquals("https://signed.example/demo-video-key", result.get(0).getUrl());
        assertEquals(42, result.get(0).getDuration());
        verify(s3Service).generatePresignedUrl("demo-video-key");
    }
}
