package com.aptraining.service;

import com.aptraining.dto.TrainingDTO;
import com.aptraining.dto.TrainingExerciseDTO;
import com.aptraining.entity.Exercise;
import com.aptraining.entity.Training;
import com.aptraining.entity.TrainingExercise;
import com.aptraining.entity.TrainingPlan;
import com.aptraining.entity.TrainingPlanWorkout;
import com.aptraining.entity.User;
import com.aptraining.entity.Video;
import com.aptraining.entity.enums.MeasurementUnitEnum;
import com.aptraining.entity.enums.RepetitionType;
import com.aptraining.repository.ExerciseRepository;
import com.aptraining.repository.TrainingRepository;
import com.aptraining.repository.TrainingPlanWorkoutRepository;
import com.aptraining.repository.UserRepository;
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

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrainingServiceTest {

    @Mock
    private TrainingRepository trainingRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private ExerciseRepository exerciseRepository;
    @Mock
    private TrainingPlanWorkoutRepository trainingPlanWorkoutRepository;

    @InjectMocks
    private TrainingService trainingService;

    @Test
    void createRejectsRpeOutsideOneToTen() {
        User owner = userWithId(UUID.randomUUID());
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));

        assertThrows(
                RuntimeException.class,
                () -> trainingService.create(trainingWith(exerciseWithRpe(11)), "owner@example.com")
        );

        verify(exerciseRepository, never()).findById(org.mockito.ArgumentMatchers.any());
        verify(trainingRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void createRejectsExercisesOwnedByAnotherUser() {
        User owner = userWithId(UUID.randomUUID());
        Exercise exercise = new Exercise();
        exercise.setId(UUID.randomUUID());
        exercise.setUser(userWithId(UUID.randomUUID()));
        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(exerciseRepository.findById(exercise.getId())).thenReturn(Optional.of(exercise));

        assertThrows(
                AccessDeniedException.class,
                () -> trainingService.create(
                        trainingWith(exerciseWithRpe(8, exercise.getId())), "owner@example.com")
        );

        verify(trainingRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void deleteRejectsTrainingReferencedByAnyPlan() {
        UUID trainingId = UUID.randomUUID();
        User owner = userWithId(UUID.randomUUID());
        owner.setEmail("owner@example.com");
        Training training = new Training();
        training.setId(trainingId);
        training.setUser(owner);
        when(trainingRepository.findById(trainingId)).thenReturn(Optional.of(training));
        TrainingPlan plan = new TrainingPlan();
        plan.setName("Plan de fuerza");
        TrainingPlanWorkout workout = new TrainingPlanWorkout();
        workout.setPlan(plan);
        when(trainingPlanWorkoutRepository.findFirstByTraining_Id(trainingId))
                .thenReturn(Optional.of(workout));

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> trainingService.delete(trainingId, "owner@example.com")
        );

        org.junit.jupiter.api.Assertions.assertEquals(
                "No se puede eliminar el entrenamiento porque está asignado "
                        + "a la planificación \"Plan de fuerza\"",
                exception.getMessage()
        );
        verify(trainingRepository, never()).delete(training);
    }

    @Test
    void deleteAllowsTrainingWithoutPlanReferences() {
        UUID trainingId = UUID.randomUUID();
        User owner = userWithId(UUID.randomUUID());
        owner.setEmail("owner@example.com");
        Training training = new Training();
        training.setId(trainingId);
        training.setUser(owner);
        when(trainingRepository.findById(trainingId)).thenReturn(Optional.of(training));

        trainingService.delete(trainingId, "owner@example.com");

        verify(trainingPlanWorkoutRepository).findFirstByTraining_Id(trainingId);
        verify(trainingRepository).delete(training);
    }

    @Test
    void getAllIncludesTrainingsAssignedThroughPlans() {
        User user = userWithId(UUID.randomUUID());
        user.setEmail("user@example.com");
        Training own = new Training();
        own.setId(UUID.randomUUID());
        own.setName("Propio");
        own.setUser(user);

        User trainer = userWithId(UUID.randomUUID());
        Training assigned = new Training();
        assigned.setId(UUID.randomUUID());
        assigned.setName("Del entrenador");
        assigned.setUser(trainer);

        when(userRepository.findByEmail("user@example.com")).thenReturn(Optional.of(user));
        when(trainingRepository.findByUserIdWithExercisesAndVideos(user.getId()))
                .thenReturn(List.of(own));
        when(trainingRepository.findAssignedToUserWithExercisesAndVideos(user.getId()))
                .thenReturn(List.of(assigned));

        List<TrainingDTO> result = trainingService.getAll("user@example.com");

        org.junit.jupiter.api.Assertions.assertEquals(2, result.size());
        assertTrue(result.get(0).getCreatedByMe());
        assertFalse(result.get(1).getCreatedByMe());
        org.junit.jupiter.api.Assertions.assertEquals(
                "Del entrenador", result.get(1).getName());
    }

    @Test
    void getAllIncludesVideoAvailabilityForEachTrainingExercise() {
        User owner = userWithId(UUID.randomUUID());
        owner.setEmail("owner@example.com");
        Training training = new Training();
        training.setId(UUID.randomUUID());
        training.setName("Fuerza");
        training.setUser(owner);

        Exercise withVideo = exerciseWithVideo("Press banca", true);
        Exercise withoutVideo = exerciseWithVideo("Sentadilla", false);
        training.setExercises(List.of(
                trainingExercise(training, withVideo, 0),
                trainingExercise(training, withoutVideo, 1)));

        when(userRepository.findByEmail("owner@example.com")).thenReturn(Optional.of(owner));
        when(trainingRepository.findByUserIdWithExercisesAndVideos(owner.getId()))
                .thenReturn(List.of(training));

        List<TrainingDTO> result = trainingService.getAll("owner@example.com");

        assertTrue(result.get(0).getExercises().get(0).isHasVideo());
        assertFalse(result.get(0).getExercises().get(1).isHasVideo());
    }

    private Exercise exerciseWithVideo(String name, boolean hasVideo) {
        Exercise exercise = new Exercise();
        exercise.setId(UUID.randomUUID());
        exercise.setName(name);
        exercise.setVideo(hasVideo ? new Video() : null);
        return exercise;
    }

    private TrainingExercise trainingExercise(
            Training training, Exercise exercise, int orderIndex) {
        TrainingExercise trainingExercise = new TrainingExercise();
        trainingExercise.setTraining(training);
        trainingExercise.setExercise(exercise);
        trainingExercise.setOrderIndex(orderIndex);
        return trainingExercise;
    }

    private User userWithId(UUID id) {
        User user = new User();
        user.setId(id);
        return user;
    }

    private TrainingDTO trainingWith(TrainingExerciseDTO exercise) {
        TrainingDTO training = new TrainingDTO();
        training.setName("Fuerza");
        training.setExercises(List.of(exercise));
        return training;
    }

    private TrainingExerciseDTO exerciseWithRpe(int rpe) {
        return exerciseWithRpe(rpe, UUID.randomUUID());
    }

    private TrainingExerciseDTO exerciseWithRpe(int rpe, UUID exerciseId) {
        TrainingExerciseDTO exercise = new TrainingExerciseDTO();
        exercise.setExerciseId(exerciseId);
        exercise.setRepetitions(8);
        exercise.setRepetitionType(RepetitionType.FIXED);
        exercise.setSeries(3);
        exercise.setRpe(rpe);
        exercise.setMeasurementUnit(MeasurementUnitEnum.KG);
        exercise.setLoad(BigDecimal.valueOf(20));
        exercise.setOrderIndex(0);
        return exercise;
    }
}