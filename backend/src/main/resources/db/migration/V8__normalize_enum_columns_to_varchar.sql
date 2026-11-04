ALTER TABLE users
    ALTER COLUMN role TYPE VARCHAR(10)
    USING role::text;

ALTER TABLE training_exercises
    ALTER COLUMN repetition_type TYPE VARCHAR(10)
    USING repetition_type::text,
    ALTER COLUMN measurement_unit TYPE VARCHAR(20)
    USING measurement_unit::text;

ALTER TABLE users
    ADD CONSTRAINT chk_users_role
        CHECK (role IS NULL OR role IN ('USER', 'ADMIN'));

ALTER TABLE training_exercises
    ADD CONSTRAINT chk_training_exercises_measurement_unit
        CHECK (
            measurement_unit IS NULL
            OR measurement_unit IN ('KG', 'LB', 'BODY_WEIGHT')
        );