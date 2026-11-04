package com.aptraining.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Builder
@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@Entity
@Table(name = "videos")
public class Video {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    private String title;

    private String description;

    @Column(name = "s3_key")
    private String s3Key;

    private Integer duration;

    private LocalDateTime createdAt;

    @Column(name = "s3_url")
    private String s3Url;

    @Column(name = "youtube_url")
    private String youtubeUrl;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }
}
