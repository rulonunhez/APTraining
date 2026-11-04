package com.aptraining.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class VideoDTO {

    private UUID id;
    private String title;
    private String description;
    private String key;
    private String url;
    private Integer duration;
}
