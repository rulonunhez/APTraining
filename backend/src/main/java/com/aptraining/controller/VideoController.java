package com.aptraining.controller;

import com.aptraining.dto.VideoDTO;
import com.aptraining.entity.Video;
import com.aptraining.service.S3Service;
import com.aptraining.service.VideoService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/videos")
@RequiredArgsConstructor
public class VideoController {

    @Autowired
    private VideoService videoService;
    @Autowired
    private final S3Service s3Service;

    @GetMapping
    public List<VideoDTO> getVideos() {
        return videoService.getVideos();
    }

//    @PostMapping("/upload")
//    public ResponseEntity<String> upload(@RequestParam("file") MultipartFile file) {
//        String key = s3Service.uploadFile(file);
//        return ResponseEntity.ok(key);
//    }

//    @PostMapping
//    public ResponseEntity<VideoDTO> create(
//            @RequestParam("file") MultipartFile file,
//            @RequestParam("title") String title,
//            @RequestParam("description") String description
//    ) {
//        return ResponseEntity.ok(
//                videoService.createVideo(file, title, description)
//        );
//    }

}
