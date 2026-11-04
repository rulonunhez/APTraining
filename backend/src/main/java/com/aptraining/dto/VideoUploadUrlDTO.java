package com.aptraining.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class VideoUploadUrlDTO {
    private String uploadUrl;
    private String key;
    private String contentType;
}
