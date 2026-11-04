package com.aptraining.entity;

import jakarta.persistence.Embeddable;
import lombok.*;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;


@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@Embeddable
public class TrainingExerciseId implements Serializable {

    private UUID trainingId;
    private UUID exerciseId;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof TrainingExerciseId that)) return false;
        return Objects.equals(trainingId, that.trainingId) &&
                Objects.equals(exerciseId, that.exerciseId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(trainingId, exerciseId);
    }
}
