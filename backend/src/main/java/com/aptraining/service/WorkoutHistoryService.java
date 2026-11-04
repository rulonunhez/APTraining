package com.aptraining.service;

import com.aptraining.auth.model.enums.Role;
import com.aptraining.dto.WorkoutHistoryDTO;
import com.aptraining.dto.WorkoutHistoryExerciseDTO;
import com.aptraining.dto.WorkoutHistoryFilterOptionsDTO;
import com.aptraining.dto.WorkoutHistorySetDTO;
import com.aptraining.entity.Exercise;
import com.aptraining.entity.Training;
import com.aptraining.entity.TrainingPlan;
import com.aptraining.entity.User;
import com.aptraining.entity.WorkoutHistory;
import com.aptraining.entity.WorkoutHistoryExercise;
import com.aptraining.entity.WorkoutHistorySet;
import com.aptraining.repository.ExerciseRepository;
import com.aptraining.repository.TrainingPlanAssignmentRepository;
import com.aptraining.repository.TrainingPlanRepository;
import com.aptraining.repository.TrainingRepository;
import com.aptraining.repository.UserRepository;
import com.aptraining.repository.WorkoutHistoryRepository;
import com.aptraining.requests.WorkoutHistorySearchRequest;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional
public class WorkoutHistoryService {

    private final WorkoutHistoryRepository workoutHistoryRepository;
    private final TrainingRepository trainingRepository;
    private final UserRepository userRepository;
    private final ExerciseRepository exerciseRepository;
    private final TrainingPlanRepository trainingPlanRepository;
    private final TrainingPlanAssignmentRepository trainingPlanAssignmentRepository;

    public WorkoutHistoryDTO create(WorkoutHistoryDTO dto, String email) {
        User user = userRepository.findByEmail(email).orElseThrow();
        validate(dto);

        Training training = trainingRepository.findById(dto.getTrainingId())
                .orElseThrow(() -> new RuntimeException("Training not found"));
        // Se puede registrar un entreno propio o uno visible por un plan asignado
        if (training.getUser() == null || !training.getUser().getId().equals(user.getId())) {
            if (!trainingPlanAssignmentRepository.isTrainingAssignedToUser(
                    training.getId(), user.getId())) {
                throw new AccessDeniedException("You cannot record another user's training");
            }
        }

        WorkoutHistory history = new WorkoutHistory();
        history.setUser(user);
        history.setTraining(training);
        history.setTrainingPlan(resolveVisiblePlan(dto.getTrainingPlanId(), user));
        history.setTrainingName(dto.getTrainingName().trim());
        history.setCompletedAt(Instant.now());
        history.setExercises(mapExercises(history, dto.getExercises(), user));
        return mapToDTO(workoutHistoryRepository.save(history));
    }

    private TrainingPlan resolveVisiblePlan(UUID trainingPlanId, User user) {
        if (trainingPlanId == null) {
            return null;
        }
        TrainingPlan plan = trainingPlanRepository.findById(trainingPlanId)
                .orElseThrow(() -> new RuntimeException("Training plan not found"));
        boolean isCreator = plan.getUser().getId().equals(user.getId());
        if (!isCreator
                && !trainingPlanAssignmentRepository.existsByPlanIdAndUserId(plan.getId(), user.getId())) {
            throw new AccessDeniedException("You cannot reference this training plan");
        }
        return plan;
    }

    @Transactional(readOnly = true)
    public List<WorkoutHistoryDTO> getAll(String email) {
        User user = userRepository.findByEmail(email).orElseThrow();
        return workoutHistoryRepository.findByUserIdOrderByCompletedAtDesc(user.getId())
                .stream()
                .map(this::mapToDTO)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<WorkoutHistoryDTO> search(WorkoutHistorySearchRequest filters, String email) {
        User currentUser = userRepository.findByEmail(email).orElseThrow();
        UUID targetUserId = resolveTargetUserId(filters.getUserId(), currentUser);

        // Sin fechas explícitas se acota al último año para tener un tope
        Instant to = filters.getTo() != null ? filters.getTo() : Instant.now();
        Instant from = filters.getFrom() != null ? filters.getFrom() : to.minus(365, ChronoUnit.DAYS);

        List<UUID> trainingIds = filters.getTrainingIds() == null
                ? List.of() : filters.getTrainingIds();
        List<UUID> exerciseIds = filters.getExerciseIds() == null
                ? List.of() : filters.getExerciseIds();

        return workoutHistoryRepository
                .findAll(
                        buildSearchSpecification(targetUserId, from, to, trainingIds, exerciseIds),
                        Sort.by(Sort.Direction.DESC, "completedAt"))
                .stream()
                .map(this::mapToDTO)
                .toList();
    }

    @Transactional(readOnly = true)
    public WorkoutHistoryFilterOptionsDTO getFilterOptions(UUID requestedUserId, String email) {
        User currentUser = userRepository.findByEmail(email).orElseThrow();
        UUID targetUserId = resolveTargetUserId(requestedUserId, currentUser);

        WorkoutHistoryFilterOptionsDTO options = new WorkoutHistoryFilterOptionsDTO();
        options.setTrainings(
                mapOptions(workoutHistoryRepository.findDistinctTrainingOptions(targetUserId)));
        options.setExercises(
                mapOptions(workoutHistoryRepository.findDistinctExerciseOptions(targetUserId)));
        return options;
    }

    private List<WorkoutHistoryFilterOptionsDTO.Option> mapOptions(List<Object[]> rows) {
        return rows.stream()
                .map(row -> new WorkoutHistoryFilterOptionsDTO.Option((UUID) row[0], (String) row[1]))
                .sorted(Comparator.comparing(WorkoutHistoryFilterOptionsDTO.Option::getName,
                        String.CASE_INSENSITIVE_ORDER))
                .toList();
    }

    private UUID resolveTargetUserId(UUID requestedUserId, User currentUser) {
        if (requestedUserId == null || requestedUserId.equals(currentUser.getId())) {
            return currentUser.getId();
        }
        // De momento cualquier usuario es visible para entrenadores y admin;
        // restringirlo a entrenados solo implicaría cambiar esta comprobación.
        if (currentUser.getRole() != Role.TRAINER && currentUser.getRole() != Role.ADMIN) {
            throw new AccessDeniedException("You cannot view another user's workout history");
        }
        return requestedUserId;
    }

    private Specification<WorkoutHistory> buildSearchSpecification(
            UUID userId,
            Instant from,
            Instant to,
            List<UUID> trainingIds,
            List<UUID> exerciseIds
    ) {
        return (root, query, criteriaBuilder) -> {
            query.distinct(true);
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(criteriaBuilder.equal(root.get("user").get("id"), userId));
            predicates.add(criteriaBuilder.greaterThanOrEqualTo(root.get("completedAt"), from));
            predicates.add(criteriaBuilder.lessThanOrEqualTo(root.get("completedAt"), to));

            // Entrenos y ejercicios conviven con lógica OR: basta con que el
            // registro contenga al menos uno de los seleccionados.
            List<Predicate> selectionPredicates = new ArrayList<>();
            if (!trainingIds.isEmpty()) {
                selectionPredicates.add(root.get("training").get("id").in(trainingIds));
            }
            if (!exerciseIds.isEmpty()) {
                selectionPredicates.add(root.join("exercises", JoinType.LEFT)
                        .get("exercise").get("id").in(exerciseIds));
            }
            if (!selectionPredicates.isEmpty()) {
                predicates.add(criteriaBuilder.or(selectionPredicates.toArray(Predicate[]::new)));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    private List<WorkoutHistoryExercise> mapExercises(
            WorkoutHistory history,
            List<WorkoutHistoryExerciseDTO> exerciseDtos,
            User user
    ) {
        Set<Integer> orderIndexes = new HashSet<>();
        Set<UUID> exerciseIds = new HashSet<>();
        List<UUID> requestedIds = exerciseDtos.stream()
                .map(WorkoutHistoryExerciseDTO::getExerciseId)
                .filter(id -> id != null)
                .toList();
        Map<UUID, Exercise> ownedExercises = new HashMap<>();
        for (Exercise exercise : exerciseRepository.findAllById(requestedIds)) {
            boolean isOwner = exercise.getUser() != null
                    && user.getId().equals(exercise.getUser().getId());
            // También se pueden referenciar ejercicios visibles por un plan asignado
            if (!isOwner && !trainingPlanAssignmentRepository.isExerciseAssignedToUser(
                    exercise.getId(), user.getId())) {
                throw new AccessDeniedException("You cannot reference another user's exercise");
            }
            ownedExercises.put(exercise.getId(), exercise);
        }

        List<WorkoutHistoryExercise> snapshots = new ArrayList<>();
        for (WorkoutHistoryExerciseDTO dto : exerciseDtos) {
            validateExercise(dto, orderIndexes, exerciseIds);

            WorkoutHistoryExercise snapshot = new WorkoutHistoryExercise();
            snapshot.setWorkoutHistory(history);
            snapshot.setExercise(ownedExercises.get(dto.getExerciseId()));
            snapshot.setExerciseName(dto.getExerciseName().trim());
            snapshot.setOrderIndex(dto.getOrderIndex());
            snapshot.setSeries(dto.getSeries());
            snapshot.setRepetitions(dto.getRepetitions());
            snapshot.setRepetitionsMax(dto.getRepetitionsMax());
            snapshot.setRepetitionType(dto.getRepetitionType());
            snapshot.setRpe(dto.getRpe());
            snapshot.setMeasurementUnit(dto.getMeasurementUnit());
            snapshot.setLoad(dto.getLoad());
            snapshot.setSets(mapSets(snapshot, dto));
            snapshots.add(snapshot);
        }
        return snapshots;
    }

    private List<WorkoutHistorySet> mapSets(
            WorkoutHistoryExercise snapshot,
            WorkoutHistoryExerciseDTO dto
    ) {
        List<WorkoutHistorySet> sets = new ArrayList<>();
        if (dto.getSets() == null) return sets;
        for (WorkoutHistorySetDTO setDto : dto.getSets()) {
            WorkoutHistorySet set = new WorkoutHistorySet();
            set.setWorkoutHistoryExercise(snapshot);
            set.setSetNumber(setDto.getSetNumber());
            set.setRepetitions(setDto.getRepetitions());
            set.setLoad(setDto.getLoad());
            sets.add(set);
        }
        return sets;
    }

    private void validate(WorkoutHistoryDTO dto) {
        if (dto.getTrainingId() == null) {
            throw new RuntimeException("Training id is required");
        }
        if (dto.getTrainingName() == null || dto.getTrainingName().isBlank()
                || dto.getTrainingName().length() > 255) {
            throw new RuntimeException("Training name is required and must not exceed 255 characters");
        }
        if (dto.getExercises() == null) dto.setExercises(List.of());
        // El historial debe registrar al menos un ejercicio realizado
        if (dto.getExercises().isEmpty()) {
            throw new RuntimeException("El historial debe incluir al menos un ejercicio");
        }
    }

    private void validateExercise(
            WorkoutHistoryExerciseDTO dto,
            Set<Integer> orderIndexes,
            Set<UUID> exerciseIds
    ) {
        if (dto.getExerciseName() == null || dto.getExerciseName().isBlank()
                || dto.getExerciseName().length() > 255) {
            throw new RuntimeException("Exercise name is required and must not exceed 255 characters");
        }
        if (dto.getOrderIndex() == null || dto.getOrderIndex() < 0
                || !orderIndexes.add(dto.getOrderIndex())) {
            throw new RuntimeException("Exercise order must be unique and non-negative");
        }
        if (dto.getExerciseId() != null && !exerciseIds.add(dto.getExerciseId())) {
            throw new RuntimeException("An exercise cannot be repeated in a history entry");
        }
        if (dto.getSeries() == null || dto.getSeries() < 1) {
            throw new RuntimeException("Series must be greater than zero");
        }
        // Los valores a nivel de ejercicio son una copia de la plantilla y
        // pueden ser nulos; lo realizado se registra en las series.
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
        validateSets(dto);
    }

    private void validateSets(WorkoutHistoryExerciseDTO dto) {
        List<WorkoutHistorySetDTO> sets = dto.getSets();
        // Cada ejercicio registrado debe tener al menos una serie realizada
        if (sets == null || sets.isEmpty()) {
            throw new RuntimeException("Cada ejercicio debe registrar al menos una serie");
        }
        if (sets.size() != dto.getSeries()) {
            throw new RuntimeException("Each series must have exactly one set record");
        }
        Set<Integer> setNumbers = new HashSet<>();
        for (WorkoutHistorySetDTO set : sets) {
            if (set.getSetNumber() == null || set.getSetNumber() < 1
                    || !setNumbers.add(set.getSetNumber())) {
                throw new RuntimeException("Set numbers must be unique and greater than zero");
            }
            if (set.getRepetitions() == null || set.getRepetitions() < 1) {
                throw new RuntimeException("Set repetitions must be greater than zero");
            }
            if (dto.getMeasurementUnit() == com.aptraining.entity.enums.MeasurementUnitEnum.BODY_WEIGHT) {
                if (set.getLoad() != null) {
                    throw new RuntimeException("Body weight sets cannot include an external load");
                }
            } else if (set.getLoad() != null && set.getLoad().signum() < 0) {
                throw new RuntimeException("Set load must be zero or greater");
            }
        }
    }

    private WorkoutHistoryDTO mapToDTO(WorkoutHistory history) {
        WorkoutHistoryDTO dto = new WorkoutHistoryDTO();
        dto.setId(history.getId());
        dto.setTrainingId(history.getTraining() == null ? null : history.getTraining().getId());
        dto.setTrainingPlanId(
                history.getTrainingPlan() == null ? null : history.getTrainingPlan().getId());
        dto.setTrainingName(history.getTrainingName());
        dto.setCompletedAt(history.getCompletedAt());
        dto.setExercises(history.getExercises().stream()
                .sorted(Comparator.comparing(WorkoutHistoryExercise::getOrderIndex))
                .map(snapshot -> {
                    WorkoutHistoryExerciseDTO exerciseDto = new WorkoutHistoryExerciseDTO();
                    exerciseDto.setExerciseId(
                            snapshot.getExercise() == null ? null : snapshot.getExercise().getId());
                    exerciseDto.setExerciseName(snapshot.getExerciseName());
                    exerciseDto.setOrderIndex(snapshot.getOrderIndex());
                    exerciseDto.setSeries(snapshot.getSeries());
                    exerciseDto.setRepetitions(snapshot.getRepetitions());
                    exerciseDto.setRepetitionsMax(snapshot.getRepetitionsMax());
                    exerciseDto.setRepetitionType(snapshot.getRepetitionType());
                    exerciseDto.setRpe(snapshot.getRpe());
                    exerciseDto.setMeasurementUnit(snapshot.getMeasurementUnit());
                    exerciseDto.setLoad(snapshot.getLoad());
                    exerciseDto.setSets(snapshot.getSets().stream()
                            .map(set -> {
                                WorkoutHistorySetDTO setDto = new WorkoutHistorySetDTO();
                                setDto.setSetNumber(set.getSetNumber());
                                setDto.setRepetitions(set.getRepetitions());
                                setDto.setLoad(set.getLoad());
                                return setDto;
                            })
                            .toList());
                    return exerciseDto;
                })
                .toList());
        return dto;
    }
}