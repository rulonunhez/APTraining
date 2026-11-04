package com.aptraining.dto;

import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Getter
@Setter
public class UserGroupDTO {

    private UUID id;
    private String name;
    private String description;
    // Escritura: ids de los miembros del grupo
    private List<UUID> memberIds = new ArrayList<>();
    // Lectura: miembros del grupo
    private List<UserDTO> members = new ArrayList<>();
    // Lectura: creador (el admin ve grupos de todos los entrenadores)
    private String createdByUsername;
}
