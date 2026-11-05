package com.aptraining.entity;

import com.fasterxml.jackson.annotation.JsonManagedReference;
import com.aptraining.auth.model.dto.UserDetailsDto;
import com.aptraining.auth.model.enums.Role;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.LocalDateTime;
import java.util.*;

@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@Entity
@Table(name = "users")
public class User implements UserDetails {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    private String username;

    private String email;

    private String passwordHash;

    private LocalDateTime createdAt;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private Role role;

    private String profileImageKey;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    @JsonManagedReference
    private List<Exercise> exercises = new ArrayList<>();

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }

    public User(UserDetailsDto dto) {
        username = dto.getUsername();
        email = dto.getEmail();
        passwordHash = dto.getPassword();
        role = dto.getRole();
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(() -> "ROLE_" + role.name());
    }

    @Override
    public String getPassword() {
        return passwordHash;
    }

    @Override
    public boolean isAccountNonExpired() {
        return UserDetails.super.isAccountNonExpired();
    }

    @Override
    public boolean isAccountNonLocked() {
        return UserDetails.super.isAccountNonLocked();
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return UserDetails.super.isCredentialsNonExpired();
    }

    @Override
    public boolean isEnabled() {
        return UserDetails.super.isEnabled();
    }

    public UserDetails buildUserDetails() {
        return org.springframework.security.core.userdetails.User.builder()
                .username(email)
                .password(passwordHash) // La contraseña debe estar encriptada en la BD
                .roles(role.name()) // Convertimos el rol a String
                .build();
    }
}