package com.aptraining.dto;

import com.aptraining.auth.model.enums.Role;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
public class UserDTO {

    private UUID id;
    private String username;
    private String email;
    private Role role;

    public UserDTO(UUID id, String username, String email, Role role) {
        this.id = id;
        this.username = username;
        this.email = email;
        this.role = role;
    }

    public UserDTO() {
    }
}
