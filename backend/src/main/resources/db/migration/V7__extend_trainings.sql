ALTER TABLE trainings
    ADD COLUMN description TEXT;

ALTER TABLE training_exercises
    ADD COLUMN repetitions_max INTEGER,
    ADD COLUMN repetition_type VARCHAR(10) NOT NULL DEFAULT 'FIXED',
    ADD COLUMN rpe INTEGER;

ALTER TABLE training_exercises
    ADD CONSTRAINT chk_training_exercises_repetition_type
        CHECK (repetition_type IN ('FIXED', 'RANGE')),
    ADD CONSTRAINT chk_training_exercises_repetition_range
        CHECK (
            (repetition_type = 'FIXED' AND repetitions_max IS NULL)
            OR (repetition_type = 'RANGE' AND repetitions_max >= repetitions)
        ),
    ADD CONSTRAINT chk_training_exercises_rpe
        CHECK (rpe IS NULL OR rpe BETWEEN 1 AND 10);