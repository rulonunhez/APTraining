package com.aptraining.requests;

import com.aptraining.auth.model.enums.Role;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UpdateUserRoleRequest {

    private Role role;
}
