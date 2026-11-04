package com.aptraining.service;

import com.aptraining.dto.TrainingPlanDTO;
import com.aptraining.dto.TrainingPlanDateDTO;
import com.aptraining.dto.TrainingPlanScheduleDTO;
import com.aptraining.dto.TrainingPlanWorkoutDTO;
import com.aptraining.entity.Training;
import com.aptraining.entity.TrainingPlan;
import com.aptraining.entity.User;
import com.aptraining.entity.enums.TrainingPlanMode;
import com.aptraining.repository.TrainingPlanAssignmentRepository;
import com.aptraining.repository.TrainingPlanRepository;
import com.aptraining.repository.TrainingRepository;
import com.aptraining.repository.UserGroupRepository;
import com.aptraining.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrainingPlanServiceTest {

    @Mock
    private TrainingPlanRepository trainingPlanRepository;
    @Mock
    private TrainingRepository trainingRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private TrainingPlanAssignmentRepository assignmentRepository;
    @Mock
    private UserGroupRepository userGroupRepository;

    @InjectMocks
    private TrainingPlanService trainingPlanService;

    @Test
    void createAllowsOverlappingPlansAndReusingTrainingAcrossPlans() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));
        when(trainingPlanRepository.save(any(TrainingPlan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        TrainingPlanDTO first = trainingPlanService.create(
                planBetween(LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId()),
                "owner@example.com");
        TrainingPlanDTO second = trainingPlanService.create(
                planBetween(LocalDate.of(2026, 1, 15), LocalDate.of(2026, 2, 15), training.getId()),
                "owner@example.com");

        assertEquals(training.getId(), first.getWorkouts().get(0).getTrainingId());
        assertEquals(training.getId(), second.getWorkouts().get(0).getTrainingId());
        verify(trainingPlanRepository, times(2)).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsDuplicateTrainingInsideOnePlan() {
        User owner = userWithId(UUID.randomUUID());
        UUID trainingId = UUID.randomUUID();
        TrainingPlanDTO dto = planBetween(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), trainingId);
        dto.setWorkouts(List.of(workout(trainingId), workout(trainingId)));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsEndDateBeforeStartDate() {
        User owner = userWithId(UUID.randomUUID());
        TrainingPlanDTO dto = planBetween(
                LocalDate.of(2026, 2, 1), LocalDate.of(2026, 1, 31), UUID.randomUUID());
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createAllowsPlanWithoutValidityDates() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = planBetween(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId());
        dto.setStartDate(null);
        dto.setEndDate(null);
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));
        when(trainingPlanRepository.save(any(TrainingPlan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        TrainingPlanDTO created = trainingPlanService.create(dto, "owner@example.com");

        assertNull(created.getStartDate());
        assertNull(created.getEndDate());
        verify(trainingPlanRepository).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsPlanWithOnlyOneValidityDate() {
        User owner = userWithId(UUID.randomUUID());
        TrainingPlanDTO dto = planBetween(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), UUID.randomUUID());
        dto.setEndDate(null);
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsTrainingOwnedByAnotherUser() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(userWithId(UUID.randomUUID()));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(AccessDeniedException.class,
                () -> trainingPlanService.create(
                        planBetween(LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId()),
                        "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsIncompleteScheduleTimeRange() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = planBetween(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId());
        dto.getWorkouts().get(0).getSchedules().get(0).setStartTime(LocalTime.of(19, 0));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

        @Test
        void createRejectsDuplicateWeekdayForTraining() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = planBetween(
            LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId());
        dto.getWorkouts().get(0).setSchedules(List.of(schedule(), schedule()));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
            () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
        }

        @Test
        void createRejectsEndTimeBeforeStartTime() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = planBetween(
            LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId());
        TrainingPlanScheduleDTO schedule = dto.getWorkouts().get(0).getSchedules().get(0);
        schedule.setStartTime(LocalTime.of(20, 0));
        schedule.setEndTime(LocalTime.of(19, 0));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
            () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
        }

    @Test
    void createDefaultsToWeeklyModeWhenModeIsMissing() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = planBetween(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId());
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));
        when(trainingPlanRepository.save(any(TrainingPlan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        TrainingPlanDTO created = trainingPlanService.create(dto, "owner@example.com");

        assertEquals(TrainingPlanMode.WEEKLY, created.getMode());
        assertEquals(1, created.getWorkouts().get(0).getSchedules().size());
        assertTrue(created.getWorkouts().get(0).getDates().isEmpty());
    }

    @Test
    void createFreePlanStoresSelectedDatesWithOptionalTimes() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = freePlan(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId(),
                freeDate(LocalDate.of(2026, 1, 5), LocalTime.of(19, 0), LocalTime.of(20, 0)),
                freeDate(LocalDate.of(2026, 1, 12), null, null));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));
        when(trainingPlanRepository.save(any(TrainingPlan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        TrainingPlanDTO created = trainingPlanService.create(dto, "owner@example.com");

        TrainingPlanWorkoutDTO workout = created.getWorkouts().get(0);
        assertEquals(TrainingPlanMode.FREE, created.getMode());
        assertTrue(workout.getSchedules().isEmpty());
        assertEquals(2, workout.getDates().size());
        assertEquals(LocalDate.of(2026, 1, 5), workout.getDates().get(0).getDate());
        assertEquals(LocalTime.of(19, 0), workout.getDates().get(0).getStartTime());
        assertEquals(LocalTime.of(20, 0), workout.getDates().get(0).getEndTime());
        assertEquals(LocalDate.of(2026, 1, 12), workout.getDates().get(1).getDate());
        assertNull(workout.getDates().get(1).getStartTime());
        assertNull(workout.getDates().get(1).getEndTime());
    }

    @Test
    void createRejectsFreePlanWithoutValidityDates() {
        User owner = userWithId(UUID.randomUUID());
        TrainingPlanDTO dto = freePlan(
                null, null, UUID.randomUUID(),
                freeDate(LocalDate.of(2026, 1, 5), null, null));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsFreeWorkoutWithoutDates() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = freePlan(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId());
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsFreeDateOutsidePlanRange() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = freePlan(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId(),
                freeDate(LocalDate.of(2026, 2, 1), null, null));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsRepeatedFreeDate() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = freePlan(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId(),
                freeDate(LocalDate.of(2026, 1, 5), null, null),
                freeDate(LocalDate.of(2026, 1, 5), null, null));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsFreeDateWithIncompleteTimeRange() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = freePlan(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId(),
                freeDate(LocalDate.of(2026, 1, 5), LocalTime.of(19, 0), null));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsFreeWorkoutWithWeeklySchedules() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = freePlan(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId(),
                freeDate(LocalDate.of(2026, 1, 5), null, null));
        dto.getWorkouts().get(0).setSchedules(List.of(schedule()));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void createRejectsWeeklyWorkoutWithSpecificDates() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = planBetween(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId());
        dto.getWorkouts().get(0).setDates(List.of(freeDate(LocalDate.of(2026, 1, 5), null, null)));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.create(dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void updateRejectsChangingPlanMode() {
        User owner = userWithId(UUID.randomUUID());
        TrainingPlan existing = new TrainingPlan();
        existing.setId(UUID.randomUUID());
        existing.setMode(TrainingPlanMode.WEEKLY);
        existing.setUser(owner);
        TrainingPlanDTO dto = planBetween(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), UUID.randomUUID());
        dto.setMode(TrainingPlanMode.FREE);
        when(trainingPlanRepository.findById(existing.getId())).thenReturn(Optional.of(existing));

        assertThrows(RuntimeException.class,
                () -> trainingPlanService.update(existing.getId(), dto, "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    @Test
    void getAllReturnsCreatedPlansEvenWithoutAnyAssignment() {
        User owner = userWithId(UUID.randomUUID());
        TrainingPlan ownPlan = new TrainingPlan();
        ownPlan.setId(UUID.randomUUID());
        ownPlan.setName("Plan propio");
        ownPlan.setUser(owner);
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingPlanRepository.findByUserIdOrderByStartDateAsc(owner.getId()))
                .thenReturn(List.of(ownPlan));
        when(assignmentRepository.findByUserId(owner.getId())).thenReturn(List.of());
        when(assignmentRepository.findByPlanId(ownPlan.getId())).thenReturn(List.of());

        List<TrainingPlanDTO> result = trainingPlanService.getAll("owner@example.com");

        assertEquals(1, result.size());
        assertEquals("Plan propio", result.get(0).getName());
        assertTrue(result.get(0).getCreatedByMe());
    }

    @Test
    void createNeverSelfAssignsTheCreator() {
        User owner = userWithId(UUID.randomUUID());
        Training training = trainingOwnedBy(owner);
        TrainingPlanDTO dto = planBetween(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), training.getId());
        dto.setAssignedUserIds(List.of(owner.getId()));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));
        when(userRepository.findAllById(any())).thenReturn(List.of(owner));
        when(trainingPlanRepository.save(any(TrainingPlan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        trainingPlanService.create(dto, "owner@example.com");

        verify(assignmentRepository, never()).save(any());
    }

    @Test
    void updateRejectsPlanOwnedByAnotherUser() {
        TrainingPlan existing = new TrainingPlan();
        existing.setId(UUID.randomUUID());
        existing.setMode(TrainingPlanMode.FREE);
        User otherOwner = userWithId(UUID.randomUUID());
        otherOwner.setEmail("other@example.com");
        existing.setUser(otherOwner);
        when(trainingPlanRepository.findById(existing.getId())).thenReturn(Optional.of(existing));

        assertThrows(AccessDeniedException.class,
                () -> trainingPlanService.update(existing.getId(),
                        freePlan(LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31), UUID.randomUUID()),
                        "owner@example.com"));

        verify(trainingPlanRepository, never()).save(any(TrainingPlan.class));
    }

    private TrainingPlanDTO freePlan(LocalDate start, LocalDate end, UUID trainingId,
                                     TrainingPlanDateDTO... dates) {
        TrainingPlanDTO dto = planBetween(start, end, trainingId);
        dto.setMode(TrainingPlanMode.FREE);
        TrainingPlanWorkoutDTO workout = dto.getWorkouts().get(0);
        workout.setSchedules(new java.util.ArrayList<>());
        workout.setDates(List.of(dates));
        return dto;
    }

    private TrainingPlanDateDTO freeDate(LocalDate date, LocalTime start, LocalTime end) {
        TrainingPlanDateDTO dateDto = new TrainingPlanDateDTO();
        dateDto.setDate(date);
        dateDto.setStartTime(start);
        dateDto.setEndTime(end);
        return dateDto;
    }

    private TrainingPlanDTO planBetween(LocalDate start, LocalDate end, UUID trainingId) {
        TrainingPlanDTO dto = new TrainingPlanDTO();
        dto.setName("Plan de fuerza");
        dto.setStartDate(start);
        dto.setEndDate(end);
        dto.setWorkouts(List.of(workout(trainingId)));
        return dto;
    }

    private TrainingPlanWorkoutDTO workout(UUID trainingId) {
        TrainingPlanWorkoutDTO workout = new TrainingPlanWorkoutDTO();
        workout.setTrainingId(trainingId);
        workout.setSchedules(List.of(schedule()));
        return workout;
    }

    private TrainingPlanScheduleDTO schedule() {
        TrainingPlanScheduleDTO schedule = new TrainingPlanScheduleDTO();
        schedule.setDayOfWeek(DayOfWeek.MONDAY);
        return schedule;
    }

    private User userWithId(UUID id) {
        User user = new User();
        user.setId(id);
        user.setEmail("owner@example.com");
        return user;
    }

    private Training trainingOwnedBy(User owner) {
        Training training = new Training();
        training.setId(UUID.randomUUID());
        training.setName("Día A");
        training.setUser(owner);
        return training;
    }
}