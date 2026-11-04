CREATE TABLE workout_history_sets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workout_history_exercise_id UUID NOT NULL,
    set_number INTEGER NOT NULL,
    repetitions INTEGER NOT NULL,
    load NUMERIC(10, 2),
    CONSTRAINT uq_workout_history_sets_number
        UNIQUE (workout_history_exercise_id, set_number),
    CONSTRAINT chk_workout_history_sets_number CHECK (set_number > 0),
    CONSTRAINT chk_workout_history_sets_repetitions CHECK (repetitions > 0),
    CONSTRAINT chk_workout_history_sets_load CHECK (load IS NULL OR load >= 0),
    CONSTRAINT fk_workout_history_sets_exercise FOREIGN KEY (workout_history_exercise_id)
        REFERENCES workout_history_exercises(id) ON DELETE CASCADE
);

CREATE INDEX idx_workout_history_sets_exercise
    ON workout_history_sets(workout_history_exercise_id);
