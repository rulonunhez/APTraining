package com.aptraining.requests;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class VideoUploadUrlRequest {
    private String contentType;
    private Long sizeBytes;
}
