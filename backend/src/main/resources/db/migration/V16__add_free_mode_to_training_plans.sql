ALTER TABLE training_plans
    ADD COLUMN mode VARCHAR(10) NOT NULL DEFAULT 'WEEKLY';

ALTER TABLE training_plans
    ADD CONSTRAINT chk_training_plans_mode CHECK (mode IN ('WEEKLY', 'FREE')),
    ADD CONSTRAINT chk_training_plans_free_dates CHECK (
        mode <> 'FREE' OR (start_date IS NOT NULL AND end_date IS NOT NULL)
    );

CREATE TABLE training_plan_workout_dates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_workout_id UUID NOT NULL,
    scheduled_date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    CONSTRAINT uq_training_plan_workout_dates_date UNIQUE (plan_workout_id, scheduled_date),
    CONSTRAINT chk_training_plan_workout_dates_times CHECK (
        (start_time IS NULL AND end_time IS NULL)
        OR (start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time)
    ),
    CONSTRAINT fk_training_plan_workout_dates_workout FOREIGN KEY (plan_workout_id)
        REFERENCES training_plan_workouts(id) ON DELETE CASCADE
);

CREATE INDEX idx_training_plan_workout_dates_workout ON training_plan_workout_dates(plan_workout_id);
