package com.aptraining.service;

import com.aptraining.dto.TrainingDTO;
import com.aptraining.dto.TrainingExerciseDTO;
import com.aptraining.entity.*;
import com.aptraining.repository.ExerciseRepository;
import com.aptraining.repository.TrainingPlanAssignmentRepository;
import com.aptraining.repository.TrainingRepository;
import com.aptraining.repository.TrainingPlanWorkoutRepository;
import com.aptraining.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional
public class TrainingService {

    private final TrainingRepository trainingRepository;
    private final UserRepository userRepository;
    private final ExerciseRepository exerciseRepository;
    private final TrainingPlanWorkoutRepository trainingPlanWorkoutRepository;
    private final TrainingPlanAssignmentRepository trainingPlanAssignmentRepository;

    public TrainingDTO create(TrainingDTO dto, String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow();
        validateTraining(dto);

        Training training = new Training();
        training.setId(UUID.randomUUID());
        training.setName(dto.getName());
        training.setDescription(dto.getDescription());
        training.setUser(user);
        training.setExercises(mapExercises(training, dto.getExercises(), user));
        return mapToDTO(trainingRepository.save(training));
    }

    @Transactional(readOnly = true)
    public List<TrainingDTO> getAll(String email) {

        User user = userRepository.findByEmail(email)
                .orElseThrow();

        List<TrainingDTO> own = trainingRepository.findByUserIdWithExercisesAndVideos(user.getId())
                .stream()
                .map(training -> {
                    TrainingDTO dto = mapToDTO(training);
                    dto.setCreatedByMe(true);
                    return dto;
                })
                .collect(java.util.stream.Collectors.toCollection(ArrayList::new));
        // También se ven los entrenos de planes que otros han asignado al usuario
        trainingRepository.findAssignedToUserWithExercisesAndVideos(user.getId())
                .stream()
                .filter(training -> !training.getUser().getId().equals(user.getId()))
                .map(training -> {
                    TrainingDTO dto = mapToDTO(training);
                    dto.setCreatedByMe(false);
                    return dto;
                })
                .forEach(own::add);
        return own;
    }

    @Transactional(readOnly = true)
    public TrainingDTO getById(UUID id, String email) {
        User user = userRepository.findByEmail(email).orElseThrow();
        Training training = trainingRepository.findByIdWithExercisesAndVideos(id)
                .orElseThrow(() -> new RuntimeException("Training not found"));
        boolean isOwner = training.getUser().getEmail().equals(email);
        if (!isOwner
                && !trainingPlanAssignmentRepository.isTrainingAssignedToUser(id, user.getId())) {
            throw new AccessDeniedException("You cannot access this training");
        }
        TrainingDTO dto = mapToDTO(training);
        dto.setCreatedByMe(isOwner);
        return dto;
    }

    public TrainingDTO update(UUID id, TrainingDTO dto, String email) {

        Training training = getOwnedTraining(id, email);
        validateTraining(dto);

        training.setName(dto.getName());
        training.setDescription(dto.getDescription());

        List<TrainingExercise> exercises = mapExercises(
            training, dto.getExercises(), training.getUser());
        training.getExercises().clear();
        training.getExercises().addAll(exercises);
        return mapToDTO(trainingRepository.save(training));
    }

    public void delete(UUID id, String email) {
        Training training = getOwnedTraining(id, email);
        trainingPlanWorkoutRepository.findFirstByTraining_Id(id).ifPresent(workout -> {
            String planName = workout.getPlan().getName();
            throw new RuntimeException(
                    "No se puede eliminar el entrenamiento porque está asignado "
                            + "a la planificación \"" + planName + "\"");
        });
        trainingRepository.delete(training);
    }

    private Training getOwnedTraining(UUID id, String email) {
        Training training = trainingRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Training not found"));
        if (!training.getUser().getEmail().equals(email)) {
            throw new AccessDeniedException("You cannot access this training");
        }
        return training;
    }

    private List<TrainingExercise> mapExercises(Training training,
                                                 List<TrainingExerciseDTO> exerciseDtos,
                                                 User user) {
        List<TrainingExercise> exercises = new ArrayList<>();
        Set<UUID> exerciseIds = new HashSet<>();
        Set<Integer> orderIndexes = new HashSet<>();

        for (int index = 0; index < exerciseDtos.size(); index++) {
            TrainingExerciseDTO dto = exerciseDtos.get(index);
            validateTrainingExercise(dto);
            if (!exerciseIds.add(dto.getExerciseId())) {
                throw new RuntimeException("An exercise cannot be repeated in a training");
            }

            int orderIndex = dto.getOrderIndex() == null ? index : dto.getOrderIndex();
            if (orderIndex < 0 || !orderIndexes.add(orderIndex)) {
                throw new RuntimeException("Exercise order must be unique and non-negative");
            }

            Exercise exercise = exerciseRepository.findById(dto.getExerciseId())
                    .orElseThrow(() -> new RuntimeException("Exercise not found"));
            if (exercise.getUser() == null || !exercise.getUser().getId().equals(user.getId())) {
                throw new AccessDeniedException("Only your own exercises can be added to a training");
            }

            TrainingExercise trainingExercise = new TrainingExercise();
            trainingExercise.setId(new TrainingExerciseId(training.getId(), exercise.getId()));
            trainingExercise.setTraining(training);
            trainingExercise.setExercise(exercise);
            trainingExercise.setRepetitions(dto.getRepetitions());
            trainingExercise.setRepetitionsMax(dto.getRepetitionsMax());
            trainingExercise.setRepetitionType(dto.getRepetitionType());
            trainingExercise.setSeries(dto.getSeries());
            trainingExercise.setRpe(dto.getRpe());
            trainingExercise.setMeasurementUnit(dto.getMeasurementUnit());
            trainingExercise.setLoad(dto.getLoad());
            trainingExercise.setOrderIndex(orderIndex);
            exercises.add(trainingExercise);
        }
        return exercises;
    }

    private void validateTraining(TrainingDTO dto) {
        if (dto.getName() == null || dto.getName().isBlank() || dto.getName().length() > 255) {
            throw new RuntimeException("Training name is required and must not exceed 255 characters");
        }
        if (dto.getExercises() == null) {
            dto.setExercises(List.of());
        }
    }

    private void validateTrainingExercise(TrainingExerciseDTO dto) {
        if (dto.getExerciseId() == null) {
            throw new RuntimeException("Exercise id is required");
        }
        if (dto.getSeries() == null || dto.getSeries() < 1) {
            throw new RuntimeException("Series must be greater than zero");
        }
        // Repeticiones, RPE y carga son opcionales en la plantilla:
        // el entrenado registra sus valores reales en el historial.
        if (dto.getRepetitions() != null && dto.getRepetitions() < 1) {
            throw new RuntimeException("Repetitions must be greater than zero");
        }
        if (dto.getRepetitionType() == null) {
            throw new RuntimeException("Repetition type is required");
        }
        if (dto.getRepetitionType() == com.aptraining.entity.enums.RepetitionType.RANGE
                && dto.getRepetitionsMax() != null && dto.getRepetitions() != null
                && dto.getRepetitionsMax() < dto.getRepetitions()) {
            throw new RuntimeException("Repetition range maximum must be at least the minimum");
        }
        if (dto.getRepetitionType() == com.aptraining.entity.enums.RepetitionType.FIXED
                && dto.getRepetitionsMax() != null) {
            throw new RuntimeException("Fixed repetitions cannot include a maximum value");
        }
        if (dto.getRpe() != null && (dto.getRpe() < 1 || dto.getRpe() > 10)) {
            throw new RuntimeException("RPE must be between 1 and 10");
        }
        if (dto.getMeasurementUnit() == null) {
            throw new RuntimeException("Load unit is required");
        }
        if (dto.getMeasurementUnit() == com.aptraining.entity.enums.MeasurementUnitEnum.BODY_WEIGHT) {
            if (dto.getLoad() != null) {
                throw new RuntimeException("Body weight exercises cannot include an external load");
            }
        } else if (dto.getLoad() != null && dto.getLoad().signum() < 0) {
            throw new RuntimeException("Load must be zero or greater");
        }
    }

    private TrainingDTO mapToDTO(Training training) {
        TrainingDTO dto = new TrainingDTO();
        dto.setId(training.getId());
        dto.setName(training.getName());
        dto.setDescription(training.getDescription());
        dto.setExercises(training.getExercises().stream()
                .sorted(Comparator.comparing(
                    TrainingExercise::getOrderIndex,
                    Comparator.nullsLast(Comparator.naturalOrder())))
                .map(trainingExercise -> {
                    TrainingExerciseDTO exerciseDto = new TrainingExerciseDTO();
                    exerciseDto.setExerciseId(trainingExercise.getExercise().getId());
                    exerciseDto.setExerciseName(trainingExercise.getExercise().getName());
                    exerciseDto.setHasVideo(trainingExercise.getExercise().getVideo() != null);
                    exerciseDto.setRepetitions(trainingExercise.getRepetitions());
                    exerciseDto.setRepetitionsMax(trainingExercise.getRepetitionsMax());
                    exerciseDto.setRepetitionType(trainingExercise.getRepetitionType());
                    exerciseDto.setSeries(trainingExercise.getSeries());
                    exerciseDto.setRpe(trainingExercise.getRpe());
                    exerciseDto.setMeasurementUnit(trainingExercise.getMeasurementUnit());
                    exerciseDto.setLoad(trainingExercise.getLoad());
                    exerciseDto.setOrderIndex(trainingExercise.getOrderIndex());
                    return exerciseDto;
                })
                .toList());
        return dto;
    }

}
