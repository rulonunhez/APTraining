package com.aptraining.service;

import com.aptraining.dto.WorkoutHistoryDTO;
import com.aptraining.dto.WorkoutHistoryExerciseDTO;
import com.aptraining.dto.WorkoutHistorySetDTO;
import com.aptraining.entity.Exercise;
import com.aptraining.entity.Training;
import com.aptraining.entity.User;
import com.aptraining.entity.WorkoutHistory;
import com.aptraining.entity.enums.MeasurementUnitEnum;
import com.aptraining.entity.enums.RepetitionType;
import com.aptraining.repository.ExerciseRepository;
import com.aptraining.repository.TrainingPlanAssignmentRepository;
import com.aptraining.repository.TrainingPlanRepository;
import com.aptraining.repository.TrainingRepository;
import com.aptraining.repository.UserRepository;
import com.aptraining.repository.WorkoutHistoryRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkoutHistoryServiceTest {

    @Mock
    private WorkoutHistoryRepository workoutHistoryRepository;
    @Mock
    private TrainingRepository trainingRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private ExerciseRepository exerciseRepository;
    @Mock
    private TrainingPlanRepository trainingPlanRepository;
    @Mock
    private TrainingPlanAssignmentRepository trainingPlanAssignmentRepository;

    @InjectMocks
    private WorkoutHistoryService workoutHistoryService;

    @Test
    void createPersistsSnapshotAndServerCompletionTime() {
        User owner = userWithId(UUID.randomUUID(), "owner@example.com");
        Training training = trainingOwnedBy(owner);
        Exercise exercise = exerciseOwnedBy(owner);
        WorkoutHistoryDTO request = request(training.getId(), exercise.getId());
        when(userRepository.findByEmail(owner.getEmail())).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));
        when(exerciseRepository.findAllById(List.of(exercise.getId())))
                .thenReturn(List.of(exercise));
        when(workoutHistoryRepository.save(any(WorkoutHistory.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        WorkoutHistoryDTO result = workoutHistoryService.create(request, owner.getEmail());

        assertEquals("Rutina copiada", result.getTrainingName());
        assertNotNull(result.getCompletedAt());
        assertEquals(1, result.getExercises().size());
        assertEquals("Press banca", result.getExercises().get(0).getExerciseName());
        assertEquals(4, result.getExercises().get(0).getSeries());
        assertEquals(8, result.getExercises().get(0).getRepetitions());
        assertEquals(10, result.getExercises().get(0).getRepetitionsMax());
        assertEquals(new BigDecimal("52.5"), result.getExercises().get(0).getLoad());
        verify(workoutHistoryRepository).save(any(WorkoutHistory.class));
    }

    @Test
    void createPersistsPerSetValues() {
        User owner = userWithId(UUID.randomUUID(), "owner@example.com");
        Training training = trainingOwnedBy(owner);
        Exercise exercise = exerciseOwnedBy(owner);
        WorkoutHistoryDTO request = request(training.getId(), exercise.getId());
        request.getExercises().get(0).setSets(List.of(
                set(1, 12, "20"), set(2, 10, "20"), set(3, 10, "18"), set(4, 8, "18")));
        when(userRepository.findByEmail(owner.getEmail())).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));
        when(exerciseRepository.findAllById(List.of(exercise.getId())))
                .thenReturn(List.of(exercise));
        when(workoutHistoryRepository.save(any(WorkoutHistory.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        WorkoutHistoryDTO result = workoutHistoryService.create(request, owner.getEmail());

        List<WorkoutHistorySetDTO> sets = result.getExercises().get(0).getSets();
        assertEquals(4, sets.size());
        assertEquals(1, sets.get(0).getSetNumber());
        assertEquals(12, sets.get(0).getRepetitions());
        assertEquals(new BigDecimal("20"), sets.get(0).getLoad());
        assertEquals(new BigDecimal("18"), sets.get(2).getLoad());
    }

    @Test
    void createRejectsSetCountDifferentFromSeries() {
        User owner = userWithId(UUID.randomUUID(), "owner@example.com");
        Training training = trainingOwnedBy(owner);
        WorkoutHistoryDTO request = request(training.getId(), UUID.randomUUID());
        request.getExercises().get(0).setSets(List.of(set(1, 12, "20")));
        when(userRepository.findByEmail(owner.getEmail())).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
                () -> workoutHistoryService.create(request, owner.getEmail()));

        verify(workoutHistoryRepository, never()).save(any(WorkoutHistory.class));
    }

    private WorkoutHistorySetDTO set(int number, int repetitions, String load) {
        WorkoutHistorySetDTO set = new WorkoutHistorySetDTO();
        set.setSetNumber(number);
        set.setRepetitions(repetitions);
        set.setLoad(new BigDecimal(load));
        return set;
    }

    @Test
    void createRejectsTrainingOwnedByAnotherUser() {
        User owner = userWithId(UUID.randomUUID(), "owner@example.com");
        Training training = trainingOwnedBy(userWithId(UUID.randomUUID(), "other@example.com"));
        when(userRepository.findByEmail(owner.getEmail())).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(AccessDeniedException.class,
                () -> workoutHistoryService.create(request(training.getId(), UUID.randomUUID()),
                        owner.getEmail()));

        verify(workoutHistoryRepository, never()).save(any(WorkoutHistory.class));
    }

    @Test
    void createRejectsInvalidSnapshotValues() {
        User owner = userWithId(UUID.randomUUID(), "owner@example.com");
        Training training = trainingOwnedBy(owner);
        WorkoutHistoryDTO request = request(training.getId(), UUID.randomUUID());
        request.getExercises().get(0).setRpe(11);
        when(userRepository.findByEmail(owner.getEmail())).thenReturn(Optional.of(owner));
        when(trainingRepository.findById(training.getId())).thenReturn(Optional.of(training));

        assertThrows(RuntimeException.class,
                () -> workoutHistoryService.create(request, owner.getEmail()));

        verify(workoutHistoryRepository, never()).save(any(WorkoutHistory.class));
    }

    private WorkoutHistoryDTO request(UUID trainingId, UUID exerciseId) {
        WorkoutHistoryDTO dto = new WorkoutHistoryDTO();
        dto.setTrainingId(trainingId);
        dto.setTrainingName("Rutina copiada");
        WorkoutHistoryExerciseDTO exercise = new WorkoutHistoryExerciseDTO();
        exercise.setExerciseId(exerciseId);
        exercise.setExerciseName("Press banca");
        exercise.setOrderIndex(0);
        exercise.setSeries(4);
        exercise.setRepetitions(8);
        exercise.setRepetitionsMax(10);
        exercise.setRepetitionType(RepetitionType.RANGE);
        exercise.setRpe(8);
        exercise.setMeasurementUnit(MeasurementUnitEnum.KG);
        exercise.setLoad(new BigDecimal("52.5"));
        exercise.setSets(List.of(
                set(1, 10, "52.5"), set(2, 10, "52.5"), set(3, 8, "52.5"), set(4, 8, "52.5")));
        dto.setExercises(List.of(exercise));
        return dto;
    }

    private User userWithId(UUID id, String email) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        return user;
    }

    private Training trainingOwnedBy(User owner) {
        Training training = new Training();
        training.setId(UUID.randomUUID());
        training.setName("Plantilla actual");
        training.setUser(owner);
        return training;
    }

    private Exercise exerciseOwnedBy(User owner) {
        Exercise exercise = new Exercise();
        exercise.setId(UUID.randomUUID());
        exercise.setName("Ejercicio actual");
        exercise.setUser(owner);
        return exercise;
    }
}