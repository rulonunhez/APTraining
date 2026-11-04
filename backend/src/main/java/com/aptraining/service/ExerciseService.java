package com.aptraining.service;

import com.aptraining.catalogs.Equipment;
import com.aptraining.catalogs.ExerciseType;
import com.aptraining.catalogs.MovementPattern;
import com.aptraining.catalogs.MuscleGroup;
import com.aptraining.catalogs.repository.EquipmentRepository;
import com.aptraining.catalogs.repository.ExerciseTypeRepository;
import com.aptraining.catalogs.repository.MovementPatternRepository;
import com.aptraining.catalogs.repository.MuscleGroupRepository;
import com.aptraining.dto.ExerciseDTO;
import com.aptraining.dto.VideoUploadUrlDTO;
import com.aptraining.requests.VideoUploadUrlRequest;
import com.aptraining.dto.lists.ExerciseListDTO;
import com.aptraining.entity.Exercise;
import com.aptraining.entity.User;
import com.aptraining.entity.Video;
import com.aptraining.entity.abstracts.CatalogEntity;
import com.aptraining.repository.ExerciseRepository;
import com.aptraining.repository.TrainingExerciseRepository;
import com.aptraining.repository.TrainingPlanAssignmentRepository;
import com.aptraining.repository.UserRepository;
import com.aptraining.repository.VideoRepository;
import com.aptraining.requests.CreateExerciseRequest;
import com.aptraining.requests.ExerciseSearchRequest;
import com.aptraining.util.YouTubeUrl;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class ExerciseService {

    private static final long MAX_VIDEO_SIZE_BYTES = 100L * 1024 * 1024;

    private final ExerciseRepository exerciseRepository;
    private final TrainingExerciseRepository trainingExerciseRepository;
    private final TrainingPlanAssignmentRepository trainingPlanAssignmentRepository;
    private final UserRepository userRepository;
    private final VideoRepository videoRepository;
    private final S3Service s3Service;
    private final EquipmentRepository equipmentRepository;
    private final ExerciseTypeRepository exerciseTypeRepository;
    private final MovementPatternRepository movementPatternRepository;
    private final MuscleGroupRepository muscleGroupRepository;

    @Transactional
    public ExerciseDTO updateExercise(
            UUID id,
            CreateExerciseRequest request,
            MultipartFile file,
            String email
    ) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Exercise exercise = exerciseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Exercise not found"));

        if (!exercise.getUser().getId().equals(user.getId())) {
            throw new RuntimeException("You cannot modify this exercise");
        }

        // Nombre
        if (request.getName() != null && !request.getName().isBlank()) {
            exercise.setName(request.getName());
        }

        if (request.getExerciseTypeId() != null) {
            ExerciseType exerciseType = exerciseTypeRepository.findById(request.getExerciseTypeId())
                    .orElseThrow(() -> new RuntimeException("ExerciseType not found"));
            exercise.setExerciseType(exerciseType);
        } else {
            exercise.setExerciseType(null);
        }

        if (request.getMovementPatternId() != null) {
            MovementPattern movementPattern = movementPatternRepository.findById(request.getMovementPatternId())
                    .orElseThrow(() -> new RuntimeException("MovementPattern not found"));
            exercise.setMovementPattern(movementPattern);
        } else {
            exercise.setMovementPattern(null);
        }

        if (request.getPrimaryMuscleGroupIds() != null && !request.getPrimaryMuscleGroupIds().isEmpty()) {
            Set<MuscleGroup> primaryGroups = new HashSet<>(
                    muscleGroupRepository.findAllById(request.getPrimaryMuscleGroupIds())
            );
            exercise.setPrimaryMuscleGroups(primaryGroups);
        } else {
            exercise.setPrimaryMuscleGroups(new HashSet<>());
        }

        if (request.getSecondaryMuscleGroupIds() != null && !request.getSecondaryMuscleGroupIds().isEmpty()) {
            Set<MuscleGroup> secondaryGroups = new HashSet<>(
                    muscleGroupRepository.findAllById(request.getSecondaryMuscleGroupIds())
            );
            exercise.setSecondaryMuscleGroups(secondaryGroups);
        } else {
            exercise.setSecondaryMuscleGroups(new HashSet<>());
        }

        if (request.getEquipmentIds() != null && !request.getEquipmentIds().isEmpty()) {
            Set<Equipment> equipmentSet = new HashSet<>(
                    equipmentRepository.findAllById(request.getEquipmentIds())
            );
            exercise.setEquipment(equipmentSet);
        } else {
            exercise.setEquipment(new HashSet<>());
        }

        // Campos de texto opcionales — null limpia el campo
        exercise.setExplanation(request.getExplanation());
        exercise.setTips(request.getTips());
        exercise.setCommonMistakes(request.getCommonMistakes());

        String youtubeUrl = getYouTubeUrl(request, file);
        boolean hasFile = hasUploadedVideo(request, file);
        String videoSource = request.getVideoSource();
        if ("none".equals(videoSource)) {
            if (youtubeUrl != null || hasFile) {
                throw new IllegalArgumentException("Selecciona solo una opción de video");
            }
            deleteExistingVideo(exercise);
        } else if ("youtube".equals(videoSource)) {
            if (youtubeUrl == null) {
                throw new IllegalArgumentException("La URL de YouTube es obligatoria");
            }
            deleteExistingVideo(exercise);
            Video video = new Video();
            video.setYoutubeUrl(youtubeUrl);
            video.setTitle("YouTube");
            exercise.setVideo(videoRepository.save(video));
        } else if ("upload".equals(videoSource)) {
            if (youtubeUrl != null) {
                throw new IllegalArgumentException("Selecciona solo una opción de video");
            }
            if (hasFile) {
                deleteExistingVideo(exercise);
                exercise.setVideo(storeUploadedVideo(request, file, user));
            } else if (exercise.getVideo() != null
                    && exercise.getVideo().getYoutubeUrl() != null) {
                throw new IllegalArgumentException("Selecciona el archivo de video");
            }
        } else if (videoSource != null) {
            throw new IllegalArgumentException("La forma de registrar el video no es válida");
        } else if (youtubeUrl != null) {
            deleteExistingVideo(exercise);
            Video video = new Video();
            video.setYoutubeUrl(youtubeUrl);
            video.setTitle("YouTube");
            exercise.setVideo(videoRepository.save(video));
        } else if (hasFile) {
            deleteExistingVideo(exercise);
            exercise.setVideo(storeUploadedVideo(request, file, user));
        }

        exercise = exerciseRepository.save(exercise);
        return mapToDTO(exercise);
    }

    @Transactional
    public void delete(UUID id, String email) {

        Exercise exercise = exerciseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Exercise not found"));

        if (!exercise.getUser().getEmail().equals(email)) {
            throw new AccessDeniedException("You cannot delete this exercise");
        }

        trainingExerciseRepository.findFirstByExercise_Id(id).ifPresent(trainingExercise -> {
            String trainingName = trainingExercise.getTraining().getName();
            throw new RuntimeException(
                    "No se puede eliminar el ejercicio porque está asignado "
                            + "al entreno \"" + trainingName + "\"");
        });

        deleteExistingVideo(exercise);
        exerciseRepository.delete(exercise);
    }

    @Transactional
    public ExerciseDTO createExercise(CreateExerciseRequest request, MultipartFile file, String email) {

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Exercise exercise = new Exercise();
        exercise.setName(request.getName());
        exercise.setUser(user);

        // ExerciseType
        if (request.getExerciseTypeId() != null) {
            ExerciseType exerciseType = exerciseTypeRepository.findById(request.getExerciseTypeId())
                    .orElseThrow(() -> new RuntimeException("ExerciseType not found"));
            exercise.setExerciseType(exerciseType);
        }

        // MovementPattern
        if (request.getMovementPatternId() != null) {
            MovementPattern movementPattern = movementPatternRepository.findById(request.getMovementPatternId())
                    .orElseThrow(() -> new RuntimeException("MovementPattern not found"));
            exercise.setMovementPattern(movementPattern);
        }

        // Primary muscle groups
        if (request.getPrimaryMuscleGroupIds() != null && !request.getPrimaryMuscleGroupIds().isEmpty()) {
            Set<MuscleGroup> primaryGroups = new HashSet<>(
                    muscleGroupRepository.findAllById(request.getPrimaryMuscleGroupIds())
            );
            exercise.setPrimaryMuscleGroups(primaryGroups);
        }

        // Secondary muscle groups
        if (request.getSecondaryMuscleGroupIds() != null && !request.getSecondaryMuscleGroupIds().isEmpty()) {
            Set<MuscleGroup> secondaryGroups = new HashSet<>(
                    muscleGroupRepository.findAllById(request.getSecondaryMuscleGroupIds())
            );
            exercise.setSecondaryMuscleGroups(secondaryGroups);
        }

        // Equipment
        if (request.getEquipmentIds() != null && !request.getEquipmentIds().isEmpty()) {
            Set<Equipment> equipmentSet = new HashSet<>(
                    equipmentRepository.findAllById(request.getEquipmentIds())
            );
            exercise.setEquipment(equipmentSet);
        }

        // Campos de texto opcionales
        exercise.setExplanation(request.getExplanation());
        exercise.setTips(request.getTips());
        exercise.setCommonMistakes(request.getCommonMistakes());

        String youtubeUrl = getYouTubeUrl(request, file);
        boolean hasFile = hasUploadedVideo(request, file);
        String videoSource = request.getVideoSource();
        if ("youtube".equals(videoSource) && youtubeUrl == null) {
            throw new IllegalArgumentException("La URL de YouTube es obligatoria");
        }
        if ("none".equals(videoSource) && (youtubeUrl != null || hasFile)) {
            throw new IllegalArgumentException("Selecciona solo una opción de video");
        }
        if ("upload".equals(videoSource) && youtubeUrl != null) {
            throw new IllegalArgumentException("Selecciona solo una opción de video");
        }
        if (videoSource != null
                && !Set.of("none", "youtube", "upload").contains(videoSource)) {
            throw new IllegalArgumentException("La forma de registrar el video no es válida");
        }
        if (youtubeUrl != null) {
            Video video = new Video();
            video.setYoutubeUrl(youtubeUrl);
            video.setTitle("YouTube");
            exercise.setVideo(videoRepository.save(video));
        } else if (hasFile) {
            exercise.setVideo(storeUploadedVideo(request, file, user));
        }

        exercise = exerciseRepository.save(exercise);
        return mapToDTO(exercise);
    }

    public List<ExerciseListDTO> getUserExercises(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        return user.getExercises().stream()
                .map(this::mapToListDTO)
                .toList();
    }

    public List<ExerciseListDTO> searchUserExercises(ExerciseSearchRequest filters, String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Specification<Exercise> specification = (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            root.fetch("video", JoinType.LEFT);
            predicates.add(criteriaBuilder.equal(root.get("user").get("id"), user.getId()));

            addTextFilter(predicates, root.get("name"), filters.getName(), criteriaBuilder);
            addTextFilter(predicates, root.get("explanation"), filters.getExplanation(), criteriaBuilder);
            addTextFilter(predicates, root.get("tips"), filters.getTips(), criteriaBuilder);
            addTextFilter(predicates, root.get("commonMistakes"), filters.getCommonMistakes(), criteriaBuilder);
            if (hasIds(filters.getExerciseTypeIds())) {
                addIdFilter(predicates, root.join("exerciseType", JoinType.LEFT).get("id"),
                        filters.getExerciseTypeIds());
            }
            if (hasIds(filters.getMovementPatternIds())) {
                addIdFilter(predicates, root.join("movementPattern", JoinType.LEFT).get("id"),
                        filters.getMovementPatternIds());
            }
            boolean hasCollectionFilters = hasIds(filters.getPrimaryMuscleGroupIds())
                    || hasIds(filters.getSecondaryMuscleGroupIds())
                    || hasIds(filters.getEquipmentIds());
            if (hasIds(filters.getPrimaryMuscleGroupIds())) {
                addIdFilter(predicates, root.join("primaryMuscleGroups", JoinType.LEFT).get("id"),
                        filters.getPrimaryMuscleGroupIds());
            }
            if (hasIds(filters.getSecondaryMuscleGroupIds())) {
                addIdFilter(predicates, root.join("secondaryMuscleGroups", JoinType.LEFT).get("id"),
                        filters.getSecondaryMuscleGroupIds());
            }
            if (hasIds(filters.getEquipmentIds())) {
                addIdFilter(predicates, root.join("equipment", JoinType.LEFT).get("id"),
                        filters.getEquipmentIds());
            }

            if (filters.getHasVideo() != null) {
                var videoId = root.join("video", JoinType.LEFT).get("id");
                predicates.add(filters.getHasVideo()
                        ? criteriaBuilder.isNotNull(videoId)
                        : criteriaBuilder.isNull(videoId));
            }

            if (hasCollectionFilters) {
                query.distinct(true);
            }
            return criteriaBuilder.and(predicates.toArray(new Predicate[0]));
        };

        return exerciseRepository.findAll(specification).stream()
                .map(this::mapToListDTO)
                .toList();
    }

    private void addTextFilter(
            List<Predicate> predicates,
            jakarta.persistence.criteria.Path<String> field,
            String value,
            jakarta.persistence.criteria.CriteriaBuilder criteriaBuilder
    ) {
        if (value != null && !value.isBlank()) {
            String escapedValue = value.trim()
                    .replace("\\", "\\\\")
                    .replace("%", "\\%")
                    .replace("_", "\\_");
            predicates.add(criteriaBuilder.like(
                    criteriaBuilder.lower(field),
                    "%" + escapedValue.toLowerCase(Locale.ROOT) + "%",
                    '\\'
            ));
        }
    }

    private void addIdFilter(
            List<Predicate> predicates,
            jakarta.persistence.criteria.Path<Long> field,
            List<Long> ids
    ) {
        predicates.add(field.in(ids));
    }

    private boolean hasIds(List<Long> ids) {
        return ids != null && !ids.isEmpty();
    }

    private ExerciseListDTO mapToListDTO(Exercise exercise) {
        return new ExerciseListDTO(
                exercise.getId(),
                exercise.getName(),
                exercise.getVideo() != null,
                toMuscleGroupRefs(exercise.getPrimaryMuscleGroups()),
                toMuscleGroupRefs(exercise.getSecondaryMuscleGroups())
        );
    }

    private List<ExerciseDTO.MuscleGroupRef> toMuscleGroupRefs(Set<MuscleGroup> muscleGroups) {
        return muscleGroups.stream()
                .map(mg -> new ExerciseDTO.MuscleGroupRef(mg.getId(), mg.getName()))
                .toList();
    }

    public ExerciseDTO getExerciseDetail(UUID id, String email) {

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Exercise exercise = exerciseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Exercise not found"));

        // Visible si es propio o si pertenece a un entreno de un plan asignado
        if (!exercise.getUser().getId().equals(user.getId())
                && !trainingPlanAssignmentRepository.isExerciseAssignedToUser(id, user.getId())) {
            throw new RuntimeException("Access denied");
        }

        return mapToDTO(exercise);
    }


    private ExerciseDTO mapToDTO(Exercise exercise) {
        ExerciseDTO dto = new ExerciseDTO();
        dto.setId(exercise.getId());
        dto.setName(exercise.getName());
        dto.setHasVideo(exercise.getVideo() != null);
        Video video = exercise.getVideo();
        dto.setVideoUrl(video == null
                ? null
                : video.getYoutubeUrl() != null
                    ? video.getYoutubeUrl()
                    : s3Service.generatePresignedUrl(video.getS3Key()));
        dto.setVideoSource(video == null
                ? null
                : video.getYoutubeUrl() != null ? "youtube" : "upload");

        if (exercise.getExerciseType() != null) {
            dto.setExerciseTypeId(exercise.getExerciseType().getId());
            dto.setExerciseTypeName(exercise.getExerciseType().getName());
        }

        if (exercise.getMovementPattern() != null) {
            dto.setMovementPatternId(exercise.getMovementPattern().getId());
            dto.setMovementPatternName(exercise.getMovementPattern().getName());
        }

        dto.setPrimaryMuscleGroups(
                exercise.getPrimaryMuscleGroups().stream()
                        .map(mg -> new ExerciseDTO.MuscleGroupRef(mg.getId(), mg.getName()))
                        .toList()
        );
        dto.setSecondaryMuscleGroups(
                exercise.getSecondaryMuscleGroups().stream()
                        .map(mg -> new ExerciseDTO.MuscleGroupRef(mg.getId(), mg.getName()))
                        .toList()
        );
        dto.setEquipment(
                exercise.getEquipment().stream()
                        .map(eq -> new ExerciseDTO.EquipmentRef(eq.getId(), eq.getName()))
                        .toList()
        );

        dto.setExplanation(exercise.getExplanation());
        dto.setTips(exercise.getTips());
        dto.setCommonMistakes(exercise.getCommonMistakes());

        return dto;
    }

    public VideoUploadUrlDTO createVideoUploadUrl(VideoUploadUrlRequest request, String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        String contentType = request.getContentType();
        if (contentType == null || !contentType.toLowerCase(Locale.ROOT).startsWith("video/")) {
            throw new IllegalArgumentException("El archivo debe ser un video");
        }
        Long size = request.getSizeBytes();
        if (size == null || size <= 0 || size > MAX_VIDEO_SIZE_BYTES) {
            throw new IllegalArgumentException("El video supera el tamaño máximo permitido");
        }

        String key = S3Service.userVideoKeyPrefix(user.getId()) + UUID.randomUUID();
        return new VideoUploadUrlDTO(
                s3Service.generateUploadUrl(key, contentType, size),
                key,
                contentType
        );
    }

    private boolean hasUploadedVideo(CreateExerciseRequest request, MultipartFile file) {
        return (file != null && !file.isEmpty())
                || (request.getUploadedVideoKey() != null && !request.getUploadedVideoKey().isBlank());
    }

    private Video storeUploadedVideo(CreateExerciseRequest request, MultipartFile file, User user) {
        Video video = new Video();
        video.setCreatedAt(LocalDateTime.now());

        if (file != null && !file.isEmpty()) {
            HashMap<String, String> s3identifiers = s3Service.uploadFile(file);
            video.setS3Key(s3identifiers.get("key"));
            video.setS3Url(s3identifiers.get("url"));
            video.setTitle(file.getOriginalFilename());
        } else {
            String key = request.getUploadedVideoKey().trim();
            if (!key.startsWith(S3Service.userVideoKeyPrefix(user.getId()))) {
                throw new IllegalArgumentException("El video subido no es válido");
            }
            if (!s3Service.fileExists(key)) {
                throw new IllegalArgumentException("El video no se ha subido correctamente");
            }
            String name = request.getUploadedVideoName();
            video.setS3Key(key);
            video.setS3Url(s3Service.getFileUrl(key));
            video.setTitle(name == null || name.isBlank() ? "Video" : name.trim());
        }
        return videoRepository.save(video);
    }

    private void deleteExistingVideo(Exercise exercise) {
        if (exercise.getVideo() != null) {
            Video video = exercise.getVideo();
            if (video.getS3Key() != null) {
                s3Service.deleteFile(video.getS3Key());
            }
            exercise.setVideo(null);
            videoRepository.delete(video);
        }
    }

    private String getYouTubeUrl(CreateExerciseRequest request, MultipartFile file) {
        String youtubeUrl = request.getYoutubeUrl();
        if (youtubeUrl == null || youtubeUrl.isBlank()) {
            return null;
        }
        if (hasUploadedVideo(request, file)) {
            throw new IllegalArgumentException("Selecciona solo una opción de video");
        }
        if (!YouTubeUrl.isValid(youtubeUrl)) {
            throw new IllegalArgumentException("La URL del video debe ser de YouTube");
        }
        return youtubeUrl.trim();
    }
}
