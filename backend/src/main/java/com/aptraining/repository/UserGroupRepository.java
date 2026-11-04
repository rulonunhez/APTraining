package com.aptraining.repository;

import com.aptraining.entity.UserGroup;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface UserGroupRepository extends JpaRepository<UserGroup, UUID> {

    List<UserGroup> findByCreatedByIdOrderByNameAsc(UUID userId);

    List<UserGroup> findAllByOrderByNameAsc();
}
