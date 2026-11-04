package com.aptraining.service;

import com.aptraining.auth.model.enums.Role;
import com.aptraining.dto.UserDTO;
import com.aptraining.dto.UserGroupDTO;
import com.aptraining.entity.TrainingPlan;
import com.aptraining.entity.TrainingPlanAssignment;
import com.aptraining.entity.User;
import com.aptraining.entity.UserGroup;
import com.aptraining.repository.TrainingPlanAssignmentRepository;
import com.aptraining.repository.UserGroupRepository;
import com.aptraining.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class UserGroupService {

    private final UserGroupRepository userGroupRepository;
    private final UserRepository userRepository;
    private final TrainingPlanAssignmentRepository assignmentRepository;

    @Transactional(readOnly = true)
    public List<UserGroupDTO> getAll(String email) {
        User user = getUser(email);
        List<UserGroup> groups = user.getRole() == Role.ADMIN
                ? userGroupRepository.findAllByOrderByNameAsc()
                : userGroupRepository.findByCreatedByIdOrderByNameAsc(user.getId());
        return groups.stream().map(this::mapToDTO).toList();
    }

    @Transactional(readOnly = true)
    public UserGroupDTO getById(UUID id, String email) {
        return mapToDTO(getManageableGroup(id, email));
    }

    public UserGroupDTO create(UserGroupDTO dto, String email) {
        User user = getUser(email);
        validate(dto);

        UserGroup group = new UserGroup();
        group.setName(dto.getName().trim());
        group.setDescription(normalizeDescription(dto.getDescription()));
        group.setCreatedBy(user);
        group.setMembers(resolveMembers(dto.getMemberIds()));
        return mapToDTO(userGroupRepository.save(group));
    }

    public UserGroupDTO update(UUID id, UserGroupDTO dto, String email) {
        UserGroup group = getManageableGroup(id, email);
        validate(dto);

        group.setName(dto.getName().trim());
        group.setDescription(normalizeDescription(dto.getDescription()));
        group.setMembers(resolveMembers(dto.getMemberIds()));
        return mapToDTO(userGroupRepository.save(group));
    }

    public void delete(UUID id, String email) {
        userGroupRepository.delete(getManageableGroup(id, email));
    }

    /**
     * Sincronización explícita y aditiva: asegura que todos los miembros
     * actuales del grupo tienen asignados los planes que se asignaron
     * originalmente a través de este grupo. Nunca elimina asignaciones.
     *
     * @return número de asignaciones creadas
     */
    public int syncAssignments(UUID groupId, String email) {
        UserGroup group = getManageableGroup(groupId, email);
        List<TrainingPlanAssignment> groupAssignments = assignmentRepository.findBySourceGroupId(groupId);

        Map<TrainingPlan, List<TrainingPlanAssignment>> byPlan = groupAssignments.stream()
                .collect(Collectors.groupingBy(TrainingPlanAssignment::getPlan));

        int created = 0;
        for (Map.Entry<TrainingPlan, List<TrainingPlanAssignment>> entry : byPlan.entrySet()) {
            TrainingPlan plan = entry.getKey();
            Set<UUID> alreadyAssigned = assignmentRepository.findByPlanId(plan.getId()).stream()
                    .map(assignment -> assignment.getUser().getId())
                    .collect(Collectors.toSet());

            for (User member : group.getMembers()) {
                if (alreadyAssigned.add(member.getId())) {
                    TrainingPlanAssignment assignment = new TrainingPlanAssignment();
                    assignment.setPlan(plan);
                    assignment.setUser(member);
                    assignment.setAssignedBy(plan.getUser());
                    assignment.setSourceGroup(group);
                    assignmentRepository.save(assignment);
                    created++;
                }
            }
        }
        return created;
    }

    private UserGroup getManageableGroup(UUID id, String email) {
        User user = getUser(email);
        UserGroup group = userGroupRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Group not found"));
        boolean isCreator = group.getCreatedBy().getId().equals(user.getId());
        if (!isCreator && user.getRole() != Role.ADMIN) {
            throw new AccessDeniedException("You cannot access this group");
        }
        return group;
    }

    private Set<User> resolveMembers(List<UUID> memberIds) {
        if (memberIds == null) {
            return new HashSet<>();
        }
        Set<UUID> uniqueIds = new HashSet<>(memberIds);
        Set<User> members = new HashSet<>(userRepository.findAllById(uniqueIds));
        if (members.size() != uniqueIds.size()) {
            throw new RuntimeException("Alguno de los usuarios seleccionados no existe");
        }
        return members;
    }

    private void validate(UserGroupDTO dto) {
        if (dto.getName() == null || dto.getName().isBlank() || dto.getName().length() > 255) {
            throw new RuntimeException("Group name is required and must not exceed 255 characters");
        }
    }

    private String normalizeDescription(String description) {
        return description == null || description.isBlank() ? null : description.trim();
    }

    private User getUser(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    }

    private UserGroupDTO mapToDTO(UserGroup group) {
        UserGroupDTO dto = new UserGroupDTO();
        dto.setId(group.getId());
        dto.setName(group.getName());
        dto.setDescription(group.getDescription());
        dto.setCreatedByUsername(group.getCreatedBy().getUsername());
        List<UserDTO> members = group.getMembers().stream()
                .map(member -> new UserDTO(
                        member.getId(), member.getUsername(), member.getEmail(), member.getRole()))
                .sorted(Comparator.comparing(UserDTO::getUsername,
                        Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)))
                .toList();
        dto.setMembers(members);
        dto.setMemberIds(members.stream().map(UserDTO::getId).toList());
        return dto;
    }
}
