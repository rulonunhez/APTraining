package com.aptraining.controller;

import com.aptraining.dto.UserGroupDTO;
import com.aptraining.service.UserGroupService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/groups")
@RequiredArgsConstructor
public class UserGroupController {

    private final UserGroupService userGroupService;

    @GetMapping
    public ResponseEntity<List<UserGroupDTO>> getAll(Authentication auth) {
        return ResponseEntity.ok(userGroupService.getAll(auth.getName()));
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserGroupDTO> getById(@PathVariable UUID id, Authentication auth) {
        return ResponseEntity.ok(userGroupService.getById(id, auth.getName()));
    }

    @PostMapping
    public ResponseEntity<UserGroupDTO> create(@RequestBody UserGroupDTO dto, Authentication auth) {
        return ResponseEntity.ok(userGroupService.create(dto, auth.getName()));
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserGroupDTO> update(
            @PathVariable UUID id,
            @RequestBody UserGroupDTO dto,
            Authentication auth
    ) {
        return ResponseEntity.ok(userGroupService.update(id, dto, auth.getName()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id, Authentication auth) {
        userGroupService.delete(id, auth.getName());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/sync-assignments")
    public ResponseEntity<Map<String, Integer>> syncAssignments(
            @PathVariable UUID id,
            Authentication auth
    ) {
        int created = userGroupService.syncAssignments(id, auth.getName());
        return ResponseEntity.ok(Map.of("created", created));
    }
}
