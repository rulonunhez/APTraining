ALTER TABLE training_plans
    ALTER COLUMN start_date DROP NOT NULL,
    ALTER COLUMN end_date DROP NOT NULL;