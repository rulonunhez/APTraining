CREATE TABLE workout_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    training_id UUID,
    training_name VARCHAR(255) NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_workout_history_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_workout_history_training FOREIGN KEY (training_id)
        REFERENCES trainings(id) ON DELETE SET NULL
);

CREATE TABLE workout_history_exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workout_history_id UUID NOT NULL,
    exercise_id UUID,
    exercise_name VARCHAR(255) NOT NULL,
    order_index INTEGER NOT NULL,
    series INTEGER NOT NULL,
    repetitions INTEGER NOT NULL,
    repetitions_max INTEGER,
    repetition_type VARCHAR(10) NOT NULL,
    rpe INTEGER NOT NULL,
    measurement_unit VARCHAR(20) NOT NULL,
    load NUMERIC(10, 2),
    CONSTRAINT uq_workout_history_exercises_order
        UNIQUE (workout_history_id, order_index),
    CONSTRAINT chk_workout_history_exercises_order CHECK (order_index >= 0),
    CONSTRAINT chk_workout_history_exercises_series CHECK (series > 0),
    CONSTRAINT chk_workout_history_exercises_repetitions CHECK (repetitions > 0),
    CONSTRAINT chk_workout_history_exercises_repetition_type
        CHECK (repetition_type IN ('FIXED', 'RANGE')),
    CONSTRAINT chk_workout_history_exercises_repetition_range CHECK (
        (repetition_type = 'FIXED' AND repetitions_max IS NULL)
        OR (repetition_type = 'RANGE'
            AND repetitions_max IS NOT NULL
            AND repetitions_max >= repetitions)
    ),
    CONSTRAINT chk_workout_history_exercises_rpe CHECK (rpe BETWEEN 1 AND 10),
    CONSTRAINT chk_workout_history_exercises_measurement_unit
        CHECK (measurement_unit IN ('KG', 'LB', 'BODY_WEIGHT')),
    CONSTRAINT chk_workout_history_exercises_load CHECK (
        (measurement_unit = 'BODY_WEIGHT' AND load IS NULL)
        OR (measurement_unit IN ('KG', 'LB')
            AND load IS NOT NULL
            AND load >= 0)
    ),
    CONSTRAINT fk_workout_history_exercises_history FOREIGN KEY (workout_history_id)
        REFERENCES workout_history(id) ON DELETE CASCADE,
    CONSTRAINT fk_workout_history_exercises_exercise FOREIGN KEY (exercise_id)
        REFERENCES exercises(id) ON DELETE SET NULL
);

CREATE INDEX idx_workout_history_user_completed
    ON workout_history(user_id, completed_at DESC);
CREATE INDEX idx_workout_history_exercises_history
    ON workout_history_exercises(workout_history_id);