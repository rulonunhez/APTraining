package com.aptraining.service;

import com.aptraining.auth.model.enums.Role;
import com.aptraining.dto.TrainingPlanDTO;
import com.aptraining.dto.TrainingPlanDateDTO;
import com.aptraining.dto.TrainingPlanScheduleDTO;
import com.aptraining.dto.TrainingPlanWorkoutDTO;
import com.aptraining.dto.UserDTO;
import com.aptraining.entity.Training;
import com.aptraining.entity.TrainingPlan;
import com.aptraining.entity.TrainingPlanAssignment;
import com.aptraining.entity.TrainingPlanSchedule;
import com.aptraining.entity.TrainingPlanWorkout;
import com.aptraining.entity.TrainingPlanWorkoutDate;
import com.aptraining.entity.User;
import com.aptraining.entity.UserGroup;
import com.aptraining.entity.enums.TrainingPlanMode;
import com.aptraining.repository.TrainingPlanAssignmentRepository;
import com.aptraining.repository.TrainingPlanRepository;
import com.aptraining.repository.TrainingRepository;
import com.aptraining.repository.UserGroupRepository;
import com.aptraining.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class TrainingPlanService {

    private static final int TEMPORARY_ORDER_OFFSET = 1000;

    private final TrainingPlanRepository trainingPlanRepository;
    private final TrainingRepository trainingRepository;
    private final UserRepository userRepository;
    private final TrainingPlanAssignmentRepository assignmentRepository;
    private final UserGroupRepository userGroupRepository;

    public TrainingPlanDTO create(TrainingPlanDTO dto, String email) {
        User user = userRepository.findByEmail(email).orElseThrow();
        if (dto.getMode() == null) {
            dto.setMode(TrainingPlanMode.WEEKLY);
        }
        validatePlan(dto);

        TrainingPlan plan = new TrainingPlan();
        plan.setId(UUID.randomUUID());
        plan.setName(dto.getName().trim());
        plan.setMode(dto.getMode());
        plan.setStartDate(dto.getStartDate());
        plan.setEndDate(dto.getEndDate());
        plan.setUser(user);
        plan.setWorkouts(mapWorkouts(plan, dto.getWorkouts(), user, Map.of(), dto));
        TrainingPlan saved = trainingPlanRepository.save(plan);
        syncAssignments(saved, dto.getAssignedUserIds(), dto.getAssignedGroupIds(), user);
        return enrichForCreator(mapToDTO(saved), saved);
    }

    @Transactional(readOnly = true)
    public List<TrainingPlanDTO> getAll(String email) {
        User user = userRepository.findByEmail(email).orElseThrow();
        List<TrainingPlanDTO> own = trainingPlanRepository.findByUserIdOrderByStartDateAsc(user.getId())
                .stream()
                .map(plan -> enrichForCreator(mapToDTO(plan), plan))
                .collect(Collectors.toCollection(ArrayList::new));
        List<TrainingPlanDTO> assigned = assignmentRepository.findByUserId(user.getId())
                .stream()
                .map(assignment -> enrichForAssignee(mapToDTO(assignment.getPlan()), assignment.getPlan()))
                .toList();
        own.addAll(assigned);
        own.sort(Comparator.comparing(TrainingPlanDTO::getStartDate,
                Comparator.nullsLast(Comparator.naturalOrder())));
        return own;
    }

    @Transactional(readOnly = true)
    public TrainingPlanDTO getById(UUID id, String email) {
        User user = userRepository.findByEmail(email).orElseThrow();
        TrainingPlan plan = trainingPlanRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Training plan not found"));
        if (plan.getUser().getEmail().equals(email)) {
            return enrichForCreator(mapToDTO(plan), plan);
        }
        if (assignmentRepository.existsByPlanIdAndUserId(plan.getId(), user.getId())) {
            return enrichForAssignee(mapToDTO(plan), plan);
        }
        throw new AccessDeniedException("You cannot access this training plan");
    }

    public TrainingPlanDTO update(UUID id, TrainingPlanDTO dto, String email) {
        TrainingPlan plan = getOwnedPlan(id, email);
        if (dto.getMode() != null && dto.getMode() != plan.getMode()) {
            throw new RuntimeException("The mode of an existing training plan cannot be changed");
        }
        dto.setMode(plan.getMode());
        validatePlan(dto);

        plan.setName(dto.getName().trim());
        plan.setStartDate(dto.getStartDate());
        plan.setEndDate(dto.getEndDate());
        Set<UUID> requestedTrainingIds = new HashSet<>();
        for (TrainingPlanWorkoutDTO workoutDto : dto.getWorkouts()) {
            requestedTrainingIds.add(workoutDto.getTrainingId());
        }
        plan.getWorkouts().removeIf(workout ->
                !requestedTrainingIds.contains(workout.getTraining().getId()));
        int temporaryOrderIndex = TEMPORARY_ORDER_OFFSET;
        for (TrainingPlanWorkout workout : plan.getWorkouts()) {
            workout.setOrderIndex(temporaryOrderIndex++);
        }
        trainingPlanRepository.saveAndFlush(plan);

        Map<UUID, TrainingPlanWorkout> existingWorkouts = new HashMap<>();
        for (TrainingPlanWorkout workout : plan.getWorkouts()) {
            existingWorkouts.put(workout.getTraining().getId(), workout);
        }
        List<TrainingPlanWorkout> workouts = mapWorkouts(
            plan, dto.getWorkouts(), plan.getUser(), existingWorkouts, dto);
        plan.getWorkouts().clear();
        plan.getWorkouts().addAll(workouts);
        TrainingPlan saved = trainingPlanRepository.save(plan);
        syncAssignments(saved, dto.getAssignedUserIds(), dto.getAssignedGroupIds(), plan.getUser());
        return enrichForCreator(mapToDTO(saved), saved);
    }

    public void delete(UUID id, String email) {
        trainingPlanRepository.delete(getOwnedPlan(id, email));
    }

    private TrainingPlan getOwnedPlan(UUID id, String email) {
        TrainingPlan plan = trainingPlanRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Training plan not found"));
        if (!plan.getUser().getEmail().equals(email)) {
            throw new AccessDeniedException("You cannot access this training plan");
        }
        return plan;
    }

    private List<TrainingPlanWorkout> mapWorkouts(
            TrainingPlan plan,
            List<TrainingPlanWorkoutDTO> workoutDtos,
            User user,
            Map<UUID, TrainingPlanWorkout> existingWorkouts,
            TrainingPlanDTO planDto
    ) {
        List<TrainingPlanWorkout> workouts = new ArrayList<>();
        Set<UUID> trainingIds = new HashSet<>();
        Set<Integer> orderIndexes = new HashSet<>();

        for (int index = 0; index < workoutDtos.size(); index++) {
            TrainingPlanWorkoutDTO dto = workoutDtos.get(index);
            if (dto.getTrainingId() == null) {
                throw new RuntimeException("Training id is required");
            }
            if (!trainingIds.add(dto.getTrainingId())) {
                throw new RuntimeException("A training cannot be repeated in a plan");
            }

            int orderIndex = dto.getOrderIndex() == null ? index : dto.getOrderIndex();
            if (orderIndex < 0 || !orderIndexes.add(orderIndex)) {
                throw new RuntimeException("Workout order must be unique and non-negative");
            }

            Training training = trainingRepository.findById(dto.getTrainingId())
                    .orElseThrow(() -> new RuntimeException("Training not found"));
            if (training.getUser() == null || !training.getUser().getId().equals(user.getId())) {
                throw new AccessDeniedException("Only your own trainings can be added to a plan");
            }

            validateWorkoutScheduling(dto, planDto);
            TrainingPlanWorkout workout = existingWorkouts.get(dto.getTrainingId());
            if (workout == null) {
                workout = new TrainingPlanWorkout();
                workout.setId(UUID.randomUUID());
            }
            workout.setPlan(plan);
            workout.setTraining(training);
            workout.setOrderIndex(orderIndex);
            List<TrainingPlanSchedule> schedules = plan.getMode() == TrainingPlanMode.WEEKLY
                    ? mapSchedules(workout, dto.getSchedules())
                    : new ArrayList<>();
            List<TrainingPlanWorkoutDate> scheduledDates = plan.getMode() == TrainingPlanMode.FREE
                    ? mapDates(workout, dto.getDates())
                    : new ArrayList<>();
            workout.getSchedules().clear();
            workout.getSchedules().addAll(schedules);
            workout.getDates().clear();
            workout.getDates().addAll(scheduledDates);
            workouts.add(workout);
        }
        return workouts;
    }

    private void validatePlan(TrainingPlanDTO dto) {
        if (dto.getName() == null || dto.getName().isBlank() || dto.getName().length() > 255) {
            throw new RuntimeException("Plan name is required and must not exceed 255 characters");
        }
        boolean hasStartDate = dto.getStartDate() != null;
        boolean hasEndDate = dto.getEndDate() != null;
        if (hasStartDate != hasEndDate
            || (hasStartDate && dto.getEndDate().isBefore(dto.getStartDate()))) {
            throw new RuntimeException(
                "Plan dates must both be set or both be empty, and end date cannot be before start date");
        }
        if (dto.getMode() == TrainingPlanMode.FREE && !hasStartDate) {
            throw new RuntimeException("Free mode training plans require a start and end date");
        }
        if (dto.getWorkouts() == null) {
            dto.setWorkouts(List.of());
        }
    }

    private void validateWorkoutScheduling(TrainingPlanWorkoutDTO workoutDto, TrainingPlanDTO planDto) {
        if (planDto.getMode() == TrainingPlanMode.FREE) {
            if (!workoutDto.getSchedules().isEmpty()) {
                throw new RuntimeException("Free mode training plans cannot use weekly schedules");
            }
            validateDates(workoutDto.getDates(), planDto);
        } else {
            if (!workoutDto.getDates().isEmpty()) {
                throw new RuntimeException("Weekly training plans cannot use specific dates");
            }
            validateSchedules(workoutDto.getSchedules());
        }
    }

    private void validateSchedules(List<TrainingPlanScheduleDTO> schedules) {
        if (schedules == null || schedules.isEmpty()) {
            throw new RuntimeException("Each training in a plan must have at least one scheduled day");
        }

        Set<java.time.DayOfWeek> days = new HashSet<>();
        for (TrainingPlanScheduleDTO schedule : schedules) {
            if (schedule.getDayOfWeek() == null || !days.add(schedule.getDayOfWeek())) {
                throw new RuntimeException("Scheduled days are required and cannot be repeated");
            }
            validateTimes(schedule.getStartTime(), schedule.getEndTime());
        }
    }

    private void validateDates(List<TrainingPlanDateDTO> dates, TrainingPlanDTO planDto) {
        if (dates == null || dates.isEmpty()) {
            throw new RuntimeException("Each training in a free mode plan must have at least one date");
        }

        Set<LocalDate> scheduledDates = new HashSet<>();
        for (TrainingPlanDateDTO date : dates) {
            if (date.getDate() == null || !scheduledDates.add(date.getDate())) {
                throw new RuntimeException("Scheduled dates are required and cannot be repeated");
            }
            if (date.getDate().isBefore(planDto.getStartDate()) || date.getDate().isAfter(planDto.getEndDate())) {
                throw new RuntimeException("Scheduled dates must be within the training plan dates");
            }
            validateTimes(date.getStartTime(), date.getEndTime());
        }
    }

    private void validateTimes(LocalTime startTime, LocalTime endTime) {
        boolean hasStart = startTime != null;
        boolean hasEnd = endTime != null;
        if (hasStart != hasEnd || (hasStart && !endTime.isAfter(startTime))) {
            throw new RuntimeException("Schedule times must be both set and end after start");
        }
    }

    private List<TrainingPlanSchedule> mapSchedules(
            TrainingPlanWorkout workout,
            List<TrainingPlanScheduleDTO> scheduleDtos
    ) {
        Map<java.time.DayOfWeek, TrainingPlanSchedule> existingSchedules = new HashMap<>();
        for (TrainingPlanSchedule schedule : workout.getSchedules()) {
            existingSchedules.put(schedule.getDayOfWeek(), schedule);
        }
        List<TrainingPlanSchedule> schedules = new ArrayList<>();
        for (TrainingPlanScheduleDTO dto : scheduleDtos) {
            TrainingPlanSchedule schedule = existingSchedules.get(dto.getDayOfWeek());
            if (schedule == null) {
                schedule = new TrainingPlanSchedule();
                schedule.setId(UUID.randomUUID());
            }
            schedule.setPlanWorkout(workout);
            schedule.setDayOfWeek(dto.getDayOfWeek());
            schedule.setStartTime(dto.getStartTime());
            schedule.setEndTime(dto.getEndTime());
            schedules.add(schedule);
        }
        return schedules;
    }

    private List<TrainingPlanWorkoutDate> mapDates(
            TrainingPlanWorkout workout,
            List<TrainingPlanDateDTO> dateDtos
    ) {
        Map<LocalDate, TrainingPlanWorkoutDate> existingDates = new HashMap<>();
        for (TrainingPlanWorkoutDate date : workout.getDates()) {
            existingDates.put(date.getScheduledDate(), date);
        }
        List<TrainingPlanWorkoutDate> dates = new ArrayList<>();
        for (TrainingPlanDateDTO dto : dateDtos) {
            TrainingPlanWorkoutDate date = existingDates.get(dto.getDate());
            if (date == null) {
                date = new TrainingPlanWorkoutDate();
                date.setId(UUID.randomUUID());
            }
            date.setPlanWorkout(workout);
            date.setScheduledDate(dto.getDate());
            date.setStartTime(dto.getStartTime());
            date.setEndTime(dto.getEndTime());
            dates.add(date);
        }
        return dates;
    }

    /**
     * Materializa las asignaciones individuales del plan: los grupos se
     * expanden a sus miembros y se combinan con los usuarios individuales.
     * Crea las asignaciones nuevas, elimina las que ya no aplican y
     * actualiza el grupo de origen si cambió. El creador nunca se auto-asigna.
     */
    private void syncAssignments(
            TrainingPlan plan,
            List<UUID> assignedUserIds,
            List<UUID> assignedGroupIds,
            User creator
    ) {
        // Usuario objetivo -> grupo de origen (null si se asignó individualmente)
        Map<UUID, UserGroup> targetSources = new HashMap<>();
        if (assignedGroupIds != null) {
            for (UUID groupId : new HashSet<>(assignedGroupIds)) {
                UserGroup group = userGroupRepository.findById(groupId)
                        .orElseThrow(() -> new RuntimeException("Group not found"));
                boolean isCreator = group.getCreatedBy().getId().equals(creator.getId());
                if (!isCreator && creator.getRole() != Role.ADMIN) {
                    throw new AccessDeniedException("You cannot assign plans through this group");
                }
                for (User member : group.getMembers()) {
                    targetSources.putIfAbsent(member.getId(), group);
                }
            }
        }
        if (assignedUserIds != null) {
            Set<UUID> individualIds = new HashSet<>(assignedUserIds);
            individualIds.removeAll(targetSources.keySet());
            if (!individualIds.isEmpty()) {
                Set<UUID> existing = userRepository.findAllById(individualIds)
                        .stream().map(User::getId).collect(Collectors.toSet());
                if (existing.size() != individualIds.size()) {
                    throw new RuntimeException("Alguno de los usuarios seleccionados no existe");
                }
            }
            for (UUID userId : individualIds) {
                targetSources.put(userId, null);
            }
        }
        targetSources.remove(creator.getId());

        List<TrainingPlanAssignment> current = assignmentRepository.findByPlanId(plan.getId());
        Map<UUID, TrainingPlanAssignment> currentByUser = current.stream()
                .collect(Collectors.toMap(a -> a.getUser().getId(), a -> a));

        for (TrainingPlanAssignment existing : current) {
            UUID assignedUserId = existing.getUser().getId();
            if (!targetSources.containsKey(assignedUserId)) {
                assignmentRepository.delete(existing);
            } else {
                UserGroup newSource = targetSources.get(assignedUserId);
                UserGroup currentSource = existing.getSourceGroup();
                boolean changed = newSource == null
                        ? currentSource != null
                        : currentSource == null || !newSource.getId().equals(currentSource.getId());
                if (changed) {
                    existing.setSourceGroup(newSource);
                    assignmentRepository.save(existing);
                }
            }
        }

        for (Map.Entry<UUID, UserGroup> entry : targetSources.entrySet()) {
            if (!currentByUser.containsKey(entry.getKey())) {
                TrainingPlanAssignment assignment = new TrainingPlanAssignment();
                assignment.setPlan(plan);
                assignment.setUser(userRepository.getReferenceById(entry.getKey()));
                assignment.setAssignedBy(creator);
                assignment.setSourceGroup(entry.getValue());
                assignmentRepository.save(assignment);
            }
        }
    }

    private TrainingPlanDTO enrichForCreator(TrainingPlanDTO dto, TrainingPlan plan) {
        dto.setCreatedByMe(true);
        List<TrainingPlanAssignment> assignments = assignmentRepository.findByPlanId(plan.getId());
        List<UserDTO> assignedUsers = assignments.stream()
                .map(assignment -> {
                    User assigned = assignment.getUser();
                    return new UserDTO(
                            assigned.getId(), assigned.getUsername(),
                            assigned.getEmail(), assigned.getRole());
                })
                .sorted(Comparator.comparing(UserDTO::getUsername,
                        Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)))
                .toList();
        dto.setAssignedUsers(assignedUsers);
        dto.setAssignedUserIds(assignedUsers.stream().map(UserDTO::getId).toList());
        dto.setAssignedGroupIds(assignments.stream()
                .map(TrainingPlanAssignment::getSourceGroup)
                .filter(group -> group != null)
                .map(UserGroup::getId)
                .distinct()
                .toList());
        return dto;
    }

    private TrainingPlanDTO enrichForAssignee(TrainingPlanDTO dto, TrainingPlan plan) {
        dto.setCreatedByMe(false);
        dto.setAssignedByUsername(plan.getUser().getUsername());
        dto.setAssignedUsers(List.of());
        dto.setAssignedUserIds(List.of());
        dto.setAssignedGroupIds(List.of());
        return dto;
    }

    private TrainingPlanDTO mapToDTO(TrainingPlan plan) {
        TrainingPlanDTO dto = new TrainingPlanDTO();
        dto.setId(plan.getId());
        dto.setName(plan.getName());
        dto.setMode(plan.getMode());
        dto.setStartDate(plan.getStartDate());
        dto.setEndDate(plan.getEndDate());
        dto.setWorkouts(plan.getWorkouts().stream()
                .sorted(Comparator.comparing(TrainingPlanWorkout::getOrderIndex))
                .map(workout -> {
                    TrainingPlanWorkoutDTO workoutDto = new TrainingPlanWorkoutDTO();
                    workoutDto.setTrainingId(workout.getTraining().getId());
                    workoutDto.setTrainingName(workout.getTraining().getName());
                    workoutDto.setOrderIndex(workout.getOrderIndex());
                    workoutDto.setSchedules(workout.getSchedules().stream()
                            .sorted(Comparator.comparing(
                                    schedule -> schedule.getDayOfWeek().getValue()))
                            .map(schedule -> {
                                TrainingPlanScheduleDTO scheduleDto = new TrainingPlanScheduleDTO();
                                scheduleDto.setDayOfWeek(schedule.getDayOfWeek());
                                scheduleDto.setStartTime(schedule.getStartTime());
                                scheduleDto.setEndTime(schedule.getEndTime());
                                return scheduleDto;
                            })
                            .toList());
                    workoutDto.setDates(workout.getDates().stream()
                            .map(date -> {
                                TrainingPlanDateDTO dateDto = new TrainingPlanDateDTO();
                                dateDto.setDate(date.getScheduledDate());
                                dateDto.setStartTime(date.getStartTime());
                                dateDto.setEndTime(date.getEndTime());
                                return dateDto;
                            })
                            .toList());
                    return workoutDto;
                })
                .toList());
        return dto;
    }
}