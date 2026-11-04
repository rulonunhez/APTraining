package com.aptraining.repository;

import com.aptraining.entity.Video;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface VideoRepository extends JpaRepository<Video, UUID> {
}
