-- Plantillas de entreno: repeticiones, RPE y carga pasan a ser opcionales.
-- El entrenador define la estructura; el entrenado registra sus valores en el historial.
ALTER TABLE training_exercises
    DROP CONSTRAINT chk_training_exercises_repetition_range;
ALTER TABLE training_exercises
    ADD CONSTRAINT chk_training_exercises_repetition_range
        CHECK (
            (repetition_type = 'FIXED' AND repetitions_max IS NULL)
            OR (repetition_type = 'RANGE'
                AND (repetitions_max IS NULL
                     OR repetitions IS NULL
                     OR repetitions_max >= repetitions))
        );

-- Historial: los valores a nivel de ejercicio son una copia de la plantilla,
-- por lo que tambien admiten nulos. Las series registradas (workout_history_sets)
-- siguen exigiendo repeticiones.
ALTER TABLE workout_history_exercises
    ALTER COLUMN repetitions DROP NOT NULL,
    ALTER COLUMN rpe DROP NOT NULL;

ALTER TABLE workout_history_exercises
    DROP CONSTRAINT chk_workout_history_exercises_repetitions,
    DROP CONSTRAINT chk_workout_history_exercises_repetition_range,
    DROP CONSTRAINT chk_workout_history_exercises_rpe,
    DROP CONSTRAINT chk_workout_history_exercises_load;

ALTER TABLE workout_history_exercises
    ADD CONSTRAINT chk_workout_history_exercises_repetitions
        CHECK (repetitions IS NULL OR repetitions > 0),
    ADD CONSTRAINT chk_workout_history_exercises_repetition_range CHECK (
        (repetition_type = 'FIXED' AND repetitions_max IS NULL)
        OR (repetition_type = 'RANGE'
            AND (repetitions_max IS NULL
                 OR repetitions IS NULL
                 OR repetitions_max >= repetitions))
    ),
    ADD CONSTRAINT chk_workout_history_exercises_rpe
        CHECK (rpe IS NULL OR rpe BETWEEN 1 AND 10),
    ADD CONSTRAINT chk_workout_history_exercises_load CHECK (
        (measurement_unit = 'BODY_WEIGHT' AND load IS NULL)
        OR (measurement_unit IN ('KG', 'LB')
            AND (load IS NULL OR load >= 0))
    );

-- Historial: referencia opcional a la planificacion que estaba siguiendo el usuario.
-- Prepara el acceso futuro del entrenador al historial de sus entrenados.
ALTER TABLE workout_history
    ADD COLUMN training_plan_id UUID,
    ADD CONSTRAINT fk_workout_history_plan FOREIGN KEY (training_plan_id)
        REFERENCES training_plans(id) ON DELETE SET NULL;

CREATE INDEX idx_workout_history_plan ON workout_history(training_plan_id);
