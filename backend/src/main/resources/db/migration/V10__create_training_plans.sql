CREATE TABLE training_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    user_created_by UUID NOT NULL,
    CONSTRAINT chk_training_plans_dates CHECK (end_date >= start_date),
    CONSTRAINT fk_training_plans_user FOREIGN KEY (user_created_by)
        REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE training_plan_workouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID NOT NULL,
    training_id UUID NOT NULL,
    order_index INTEGER NOT NULL,
    CONSTRAINT uq_training_plan_workouts_training UNIQUE (plan_id, training_id),
    CONSTRAINT uq_training_plan_workouts_order UNIQUE (plan_id, order_index),
    CONSTRAINT chk_training_plan_workouts_order CHECK (order_index >= 0),
    CONSTRAINT fk_training_plan_workouts_plan FOREIGN KEY (plan_id)
        REFERENCES training_plans(id) ON DELETE CASCADE,
    CONSTRAINT fk_training_plan_workouts_training FOREIGN KEY (training_id)
        REFERENCES trainings(id) ON DELETE RESTRICT
);

CREATE TABLE training_plan_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_workout_id UUID NOT NULL,
    day_of_week VARCHAR(9) NOT NULL,
    start_time TIME,
    end_time TIME,
    CONSTRAINT uq_training_plan_schedules_day UNIQUE (plan_workout_id, day_of_week),
    CONSTRAINT chk_training_plan_schedules_day CHECK (
        day_of_week IN ('MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY')
    ),
    CONSTRAINT chk_training_plan_schedules_times CHECK (
        (start_time IS NULL AND end_time IS NULL)
        OR (start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time)
    ),
    CONSTRAINT fk_training_plan_schedules_workout FOREIGN KEY (plan_workout_id)
        REFERENCES training_plan_workouts(id) ON DELETE CASCADE
);

CREATE INDEX idx_training_plans_user ON training_plans(user_created_by);
CREATE INDEX idx_training_plan_workouts_training ON training_plan_workouts(training_id);