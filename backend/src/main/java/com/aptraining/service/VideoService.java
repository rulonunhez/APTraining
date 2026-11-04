package com.aptraining.service;

import com.aptraining.dto.VideoDTO;
import com.aptraining.entity.Video;
import com.aptraining.repository.VideoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class VideoService {

    private final VideoRepository videoRepository;
    private final S3Service s3Service;

    public List<VideoDTO> getVideos() {
        return videoRepository.findAll().stream()
                .map(video -> new VideoDTO(video.getId(), video.getTitle(),
                                                video.getDescription(), video.getS3Key(),
                                                s3Service.generatePresignedUrl(video.getS3Key()),
                                                video.getDuration()))
                .collect(Collectors.toList());
    }

}
