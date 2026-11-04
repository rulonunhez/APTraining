package com.aptraining.service;

import com.aptraining.catalogs.repository.EquipmentRepository;
import com.aptraining.catalogs.MuscleGroup;
import com.aptraining.catalogs.repository.ExerciseTypeRepository;
import com.aptraining.catalogs.repository.MovementPatternRepository;
import com.aptraining.catalogs.repository.MuscleGroupRepository;
import com.aptraining.entity.Exercise;
import com.aptraining.entity.Training;
import com.aptraining.entity.TrainingExercise;
import com.aptraining.entity.User;
import com.aptraining.entity.Video;
import com.aptraining.repository.ExerciseRepository;
import com.aptraining.repository.TrainingExerciseRepository;
import com.aptraining.repository.UserRepository;
import com.aptraining.repository.VideoRepository;
import com.aptraining.requests.ExerciseSearchRequest;
import com.aptraining.requests.CreateExerciseRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.springframework.data.jpa.domain.Specification;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.argThat;

@ExtendWith(MockitoExtension.class)
class ExerciseServiceTest {

    @Mock
    private ExerciseRepository exerciseRepository;
    @Mock
    private TrainingExerciseRepository trainingExerciseRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private VideoRepository videoRepository;
    @Mock
    private S3Service s3Service;
    @Mock
    private EquipmentRepository equipmentRepository;
    @Mock
    private ExerciseTypeRepository exerciseTypeRepository;
    @Mock
    private MovementPatternRepository movementPatternRepository;
    @Mock
    private MuscleGroupRepository muscleGroupRepository;

    @InjectMocks
    private ExerciseService exerciseService;

    @Test
    void searchUserExercisesScopesResultsToAuthenticatedUserAndMapsListDto() {
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        Exercise exercise = exerciseOwnedBy(user);
        exercise.setId(UUID.randomUUID());
        exercise.setName("Press banca");
        Video video = new Video();
        exercise.setVideo(video);
        ExerciseSearchRequest filters = new ExerciseSearchRequest();
        filters.setName("press");
        filters.setPrimaryMuscleGroupIds(List.of(1L, 2L));
        filters.setHasVideo(true);

        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(exerciseRepository.findAll(
                org.mockito.ArgumentMatchers.<Specification<Exercise>>any()
        )).thenReturn(List.of(exercise));

        var result = exerciseService.searchUserExercises(filters, user.getEmail());

        assertEquals(1, result.size());
        assertEquals(exercise.getId(), result.get(0).getId());
        assertEquals("Press banca", result.get(0).getName());
        org.junit.jupiter.api.Assertions.assertTrue(result.get(0).isHasVideo());
        verify(exerciseRepository).findAll(
                org.mockito.ArgumentMatchers.<Specification<Exercise>>any()
        );
    }

    @Test
    void getExerciseDetailReturnsPresignedUrlForVideo() {
        UUID exerciseId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();
        User user = userWithId(userId, "owner@example.com");
        Exercise exercise = exerciseOwnedBy(user);
        Video video = new Video();
        video.setS3Key("exercise-video-key");
        video.setS3Url("https://bucket.s3.amazonaws.com/exercise-video-key");
        exercise.setVideo(video);
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(exerciseRepository.findById(exerciseId)).thenReturn(Optional.of(exercise));
        when(s3Service.generatePresignedUrl("exercise-video-key"))
                .thenReturn("https://signed.example/exercise-video-key");

        var result = exerciseService.getExerciseDetail(exerciseId, user.getEmail());

        assertEquals("https://signed.example/exercise-video-key", result.getVideoUrl());
        org.junit.jupiter.api.Assertions.assertTrue(result.isHasVideo());
        verify(s3Service).generatePresignedUrl("exercise-video-key");
    }

    @Test
    void getExerciseDetailWithoutVideoDoesNotGenerateUrl() {
        UUID exerciseId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();
        User user = userWithId(userId, "owner@example.com");
        Exercise exercise = exerciseOwnedBy(user);
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(exerciseRepository.findById(exerciseId)).thenReturn(Optional.of(exercise));

        var result = exerciseService.getExerciseDetail(exerciseId, user.getEmail());

        org.junit.jupiter.api.Assertions.assertFalse(result.isHasVideo());
        assertNull(result.getVideoUrl());
        verify(s3Service, never()).generatePresignedUrl(org.mockito.ArgumentMatchers.anyString());
    }

    @Test
    void createExerciseStoresYouTubeUrlAndReturnsIt() {
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        CreateExerciseRequest request = new CreateExerciseRequest();
        request.setName("Press banca");
        request.setVideoSource("youtube");
        request.setYoutubeUrl("https://youtu.be/dQw4w9WgXcQ");
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(videoRepository.save(any(Video.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(exerciseRepository.save(any(Exercise.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        var result = exerciseService.createExercise(request, null, user.getEmail());

        assertEquals("https://youtu.be/dQw4w9WgXcQ", result.getVideoUrl());
        org.junit.jupiter.api.Assertions.assertTrue(result.isHasVideo());
        verify(videoRepository).save(argThat(video ->
                "https://youtu.be/dQw4w9WgXcQ".equals(video.getYoutubeUrl())
                        && video.getS3Key() == null));
        verify(s3Service, never()).uploadFile(any());
    }

    @Test
    void createExerciseStoresDirectlyUploadedVideoKey() {
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        String key = S3Service.userVideoKeyPrefix(user.getId()) + UUID.randomUUID();
        CreateExerciseRequest request = new CreateExerciseRequest();
        request.setName("Press banca");
        request.setVideoSource("upload");
        request.setUploadedVideoKey(key);
        request.setUploadedVideoName("press.mp4");
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(s3Service.fileExists(key)).thenReturn(true);
        when(s3Service.getFileUrl(key)).thenReturn("https://bucket/" + key);
        when(s3Service.generatePresignedUrl(key)).thenReturn("https://signed/" + key);
        when(videoRepository.save(any(Video.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(exerciseRepository.save(any(Exercise.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        var result = exerciseService.createExercise(request, null, user.getEmail());

        assertEquals("https://signed/" + key, result.getVideoUrl());
        verify(videoRepository).save(argThat(video ->
                key.equals(video.getS3Key()) && "press.mp4".equals(video.getTitle())));
        verify(s3Service, never()).uploadFile(any());
    }

    @Test
    void createExerciseRejectsUploadedKeyFromAnotherUser() {
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        CreateExerciseRequest request = new CreateExerciseRequest();
        request.setName("Press banca");
        request.setVideoSource("upload");
        request.setUploadedVideoKey(S3Service.userVideoKeyPrefix(UUID.randomUUID()) + "x");
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));

        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
                () -> exerciseService.createExercise(request, null, user.getEmail()));
        verify(videoRepository, never()).save(any());
    }

    @Test
    void createExerciseRejectsUploadedKeyMissingInS3() {
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        String key = S3Service.userVideoKeyPrefix(user.getId()) + "missing";
        CreateExerciseRequest request = new CreateExerciseRequest();
        request.setName("Press banca");
        request.setVideoSource("upload");
        request.setUploadedVideoKey(key);
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(s3Service.fileExists(key)).thenReturn(false);

        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
                () -> exerciseService.createExercise(request, null, user.getEmail()));
    }

    @Test
    void createVideoUploadUrlReturnsUserScopedKey() {
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(s3Service.generateUploadUrl(
                org.mockito.ArgumentMatchers.startsWith(S3Service.userVideoKeyPrefix(user.getId())),
                org.mockito.ArgumentMatchers.eq("video/mp4"),
                org.mockito.ArgumentMatchers.eq(1024L)))
                .thenReturn("https://signed.example/put");

        var result = exerciseService.createVideoUploadUrl(
                new com.aptraining.requests.VideoUploadUrlRequest("video/mp4", 1024L),
                user.getEmail());

        assertEquals("https://signed.example/put", result.getUploadUrl());
        org.junit.jupiter.api.Assertions.assertTrue(
                result.getKey().startsWith(S3Service.userVideoKeyPrefix(user.getId())));
    }

    @Test
    void createVideoUploadUrlRejectsNonVideoAndOversizedFiles() {
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));

        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
                () -> exerciseService.createVideoUploadUrl(
                        new com.aptraining.requests.VideoUploadUrlRequest("image/png", 10L),
                        user.getEmail()));
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
                () -> exerciseService.createVideoUploadUrl(
                        new com.aptraining.requests.VideoUploadUrlRequest("video/mp4", 500L * 1024 * 1024),
                        user.getEmail()));
    }

    @Test
    void updateExerciseReplacesStoredVideoWithYouTubeUrl() {
        UUID exerciseId = UUID.randomUUID();
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        Exercise exercise = exerciseOwnedBy(user);
        Video oldVideo = new Video();
        oldVideo.setS3Key("old-video-key");
        exercise.setVideo(oldVideo);
        CreateExerciseRequest request = new CreateExerciseRequest();
        request.setName("Press banca");
        request.setVideoSource("youtube");
        request.setYoutubeUrl("https://www.youtube.com/watch?v=dQw4w9WgXcQ");
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(exerciseRepository.findById(exerciseId)).thenReturn(Optional.of(exercise));
        when(videoRepository.save(any(Video.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(exerciseRepository.save(any(Exercise.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        var result = exerciseService.updateExercise(
                exerciseId, request, null, user.getEmail());

        assertEquals("https://www.youtube.com/watch?v=dQw4w9WgXcQ", result.getVideoUrl());
        verify(s3Service).deleteFile("old-video-key");
        verify(videoRepository).delete(oldVideo);
        verify(s3Service, never()).generatePresignedUrl(any());
    }

    @Test
    void createExerciseRejectsNonYouTubeVideoUrl() {
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        CreateExerciseRequest request = new CreateExerciseRequest();
        request.setName("Press banca");
        request.setYoutubeUrl("https://example.com/video");
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));

        assertThrows(
                IllegalArgumentException.class,
                () -> exerciseService.createExercise(request, null, user.getEmail())
        );

        verify(videoRepository, never()).save(any(Video.class));
        verify(exerciseRepository, never()).save(any(Exercise.class));
    }

    @Test
    void deleteRejectsAnotherUserBeforeDeletingVideoOrExercise() {
        UUID exerciseId = UUID.randomUUID();
        Exercise exercise = exerciseOwnedBy("owner@example.com");
        Video video = new Video();
        video.setS3Key("exercise-video-key");
        exercise.setVideo(video);
        when(exerciseRepository.findById(exerciseId)).thenReturn(Optional.of(exercise));

        assertThrows(
                AccessDeniedException.class,
                () -> exerciseService.delete(exerciseId, "other@example.com")
        );

        verify(s3Service, never()).deleteFile("exercise-video-key");
        verify(videoRepository, never()).delete(video);
        verify(exerciseRepository, never()).delete(exercise);
    }

    @Test
    void deleteRemovesVideoAndExerciseForOwner() {
        UUID exerciseId = UUID.randomUUID();
        Exercise exercise = exerciseOwnedBy("owner@example.com");
        Video video = new Video();
        video.setS3Key("exercise-video-key");
        exercise.setVideo(video);
        when(exerciseRepository.findById(exerciseId)).thenReturn(Optional.of(exercise));

        exerciseService.delete(exerciseId, "owner@example.com");

        InOrder order = inOrder(s3Service, videoRepository, exerciseRepository);
        order.verify(s3Service).deleteFile("exercise-video-key");
        order.verify(videoRepository).delete(video);
        order.verify(exerciseRepository).delete(exercise);
    }

    @Test
    void deleteRejectsExerciseUsedInTrainingBeforeDeletingVideoOrExercise() {
        UUID exerciseId = UUID.randomUUID();
        Exercise exercise = exerciseOwnedBy("owner@example.com");
        Video video = new Video();
        video.setS3Key("exercise-video-key");
        exercise.setVideo(video);
        when(exerciseRepository.findById(exerciseId)).thenReturn(Optional.of(exercise));
        Training training = new Training();
        training.setName("Entreno push");
        TrainingExercise trainingExercise = new TrainingExercise();
        trainingExercise.setTraining(training);
        when(trainingExerciseRepository.findFirstByExercise_Id(exerciseId))
                .thenReturn(Optional.of(trainingExercise));

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> exerciseService.delete(exerciseId, "owner@example.com")
        );

        org.junit.jupiter.api.Assertions.assertEquals(
                "No se puede eliminar el ejercicio porque está asignado "
                        + "al entreno \"Entreno push\"",
                exception.getMessage()
        );
        verify(s3Service, never()).deleteFile("exercise-video-key");
        verify(videoRepository, never()).delete(video);
        verify(exerciseRepository, never()).delete(exercise);
    }

    @Test
    void getUserExercisesIncludesPrimaryAndSecondaryMuscleGroupsInListDto() {
        User user = userWithId(UUID.randomUUID(), "owner@example.com");
        Exercise exercise = exerciseOwnedBy(user);
        exercise.setId(UUID.randomUUID());
        exercise.setName("Press banca");
        exercise.getPrimaryMuscleGroups().add(muscleGroup(3L, "Pecho"));
        exercise.getSecondaryMuscleGroups().add(muscleGroup(7L, "Tríceps"));
        user.setExercises(new java.util.ArrayList<>(List.of(exercise)));

        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));

        var result = exerciseService.getUserExercises(user.getEmail());

        assertEquals(1, result.size());
        assertEquals(1, result.get(0).getPrimaryMuscleGroups().size());
        assertEquals(3L, result.get(0).getPrimaryMuscleGroups().get(0).getId());
        assertEquals("Pecho", result.get(0).getPrimaryMuscleGroups().get(0).getName());
        assertEquals(1, result.get(0).getSecondaryMuscleGroups().size());
        assertEquals(7L, result.get(0).getSecondaryMuscleGroups().get(0).getId());
        assertEquals("Tríceps", result.get(0).getSecondaryMuscleGroups().get(0).getName());
    }

    private MuscleGroup muscleGroup(Long id, String name) {
        MuscleGroup muscleGroup = new MuscleGroup();
        muscleGroup.setId(id);
        muscleGroup.setName(name);
        return muscleGroup;
    }

    private Exercise exerciseOwnedBy(String email) {
        return exerciseOwnedBy(userWithId(UUID.randomUUID(), email));
    }

    private Exercise exerciseOwnedBy(User owner) {
        Exercise exercise = new Exercise();
        exercise.setUser(owner);
        return exercise;
    }

    private User userWithId(UUID id, String email) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        return user;
    }
}