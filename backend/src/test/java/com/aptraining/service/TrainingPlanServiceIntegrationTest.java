package com.aptraining.service;

import com.aptraining.auth.model.enums.Role;
import com.aptraining.dto.TrainingPlanDTO;
import com.aptraining.dto.TrainingPlanScheduleDTO;
import com.aptraining.dto.TrainingPlanWorkoutDTO;
import com.aptraining.entity.Training;
import com.aptraining.entity.User;
import com.aptraining.repository.TrainingRepository;
import com.aptraining.repository.UserRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
@Transactional
class TrainingPlanServiceIntegrationTest {

    @DynamicPropertySource
    static void jwtSecret(DynamicPropertyRegistry registry) {
        byte[] key = new byte[64];
        new SecureRandom().nextBytes(key);
        registry.add("jwt.secret", () -> Base64.getEncoder().encodeToString(key));
    }

    @Autowired
    private TrainingPlanService trainingPlanService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TrainingRepository trainingRepository;

    @Autowired
    private EntityManager entityManager;

    @Test
    void updateAddsSecondTrainingToExistingPlan() {
        User user = saveUser();
        UUID first = saveTraining(user, "Fuerza A").getId();
        UUID second = saveTraining(user, "Fuerza B").getId();
        TrainingPlanDTO created = trainingPlanService.create(
                planWith(workout(first, 0, DayOfWeek.MONDAY)), user.getEmail());

        trainingPlanService.update(created.getId(), planWith(
                workout(first, 0, DayOfWeek.MONDAY),
                workout(second, 1, DayOfWeek.TUESDAY)), user.getEmail());

        assertOrderedWorkouts(created.getId(), user.getEmail(),
                List.of(first, second), List.of(0, 1));
    }

    @Test
    void updateReplacesTrainingUsingSameOrderIndex() {
        User user = saveUser();
        UUID first = saveTraining(user, "Fuerza A").getId();
        UUID second = saveTraining(user, "Fuerza B").getId();
        TrainingPlanDTO created = trainingPlanService.create(
                planWith(workout(first, 0, DayOfWeek.MONDAY)), user.getEmail());

        trainingPlanService.update(created.getId(), planWith(
                workout(second, 0, DayOfWeek.TUESDAY)), user.getEmail());

        assertOrderedWorkouts(created.getId(), user.getEmail(),
                List.of(second), List.of(0));
    }

    @Test
    void updateSwapsOrderOfTwoTrainings() {
        User user = saveUser();
        UUID first = saveTraining(user, "Fuerza A").getId();
        UUID second = saveTraining(user, "Fuerza B").getId();
        TrainingPlanDTO created = trainingPlanService.create(planWith(
                workout(first, 0, DayOfWeek.MONDAY),
                workout(second, 1, DayOfWeek.TUESDAY)), user.getEmail());

        trainingPlanService.update(created.getId(), planWith(
                workout(second, 0, DayOfWeek.TUESDAY),
                workout(first, 1, DayOfWeek.MONDAY)), user.getEmail());

        assertOrderedWorkouts(created.getId(), user.getEmail(),
                List.of(second, first), List.of(0, 1));
    }

    private void assertOrderedWorkouts(UUID planId, String email, List<UUID> trainingIds, List<Integer> orders) {
        entityManager.flush();
        entityManager.clear();
        TrainingPlanDTO plan = trainingPlanService.getById(planId, email);
        List<UUID> actualTrainings = plan.getWorkouts().stream()
                .map(TrainingPlanWorkoutDTO::getTrainingId)
                .toList();
        List<Integer> actualOrders = plan.getWorkouts().stream()
                .map(TrainingPlanWorkoutDTO::getOrderIndex)
                .toList();
        assertEquals(trainingIds, actualTrainings);
        assertEquals(orders, actualOrders);
    }

    private TrainingPlanDTO planWith(TrainingPlanWorkoutDTO... workouts) {
        TrainingPlanDTO dto = new TrainingPlanDTO();
        dto.setName("Plan de prueba");
        dto.setWorkouts(new ArrayList<>(List.of(workouts)));
        return dto;
    }

    private TrainingPlanWorkoutDTO workout(UUID trainingId, int orderIndex, DayOfWeek day) {
        TrainingPlanScheduleDTO schedule = new TrainingPlanScheduleDTO();
        schedule.setDayOfWeek(day);
        TrainingPlanWorkoutDTO workout = new TrainingPlanWorkoutDTO();
        workout.setTrainingId(trainingId);
        workout.setOrderIndex(orderIndex);
        workout.setSchedules(List.of(schedule));
        return workout;
    }

    private User saveUser() {
        User user = new User();
        user.setUsername("it-user-" + UUID.randomUUID());
        user.setEmail("it-" + UUID.randomUUID() + "@example.com");
        user.setPasswordHash("not-used");
        user.setCreatedAt(LocalDateTime.now());
        user.setRole(Role.USER);
        return userRepository.save(user);
    }

    private Training saveTraining(User owner, String name) {
        Training training = new Training();
        training.setName(name);
        training.setUser(owner);
        training.setCreatedAt(LocalDateTime.now());
        return trainingRepository.save(training);
    }
}
