-- ==========================================
-- EXTENSIONS
-- ==========================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- TABLES
-- ==========================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE videos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255),
    description TEXT,
    s3_key TEXT NOT NULL,
    duration INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_created_by UUID NOT NULL,
    video_id UUID
);

CREATE TABLE trainings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_created_by UUID NOT NULL
);

CREATE TABLE training_exercises (
    training_id UUID NOT NULL,
    exercise_id UUID NOT NULL,
    repetitions INTEGER,
    series INTEGER,
    measurement_unit VARCHAR(20),
    load NUMERIC,
    order_index INTEGER,
    PRIMARY KEY (training_id, exercise_id)
);

-- ==========================================
-- FOREIGN KEYS
-- ==========================================

ALTER TABLE exercises
ADD CONSTRAINT fk_exercises_user
FOREIGN KEY (user_created_by)
REFERENCES users(id)
ON DELETE CASCADE;

ALTER TABLE exercises
ADD CONSTRAINT fk_exercises_video
FOREIGN KEY (video_id)
REFERENCES videos(id)
ON DELETE SET NULL;

ALTER TABLE trainings
ADD CONSTRAINT fk_trainings_user
FOREIGN KEY (user_created_by)
REFERENCES users(id)
ON DELETE CASCADE;

ALTER TABLE training_exercises
ADD CONSTRAINT fk_training_exercises_training
FOREIGN KEY (training_id)
REFERENCES trainings(id)
ON DELETE CASCADE;

ALTER TABLE training_exercises
ADD CONSTRAINT fk_training_exercises_exercise
FOREIGN KEY (exercise_id)
REFERENCES exercises(id)
ON DELETE CASCADE;

-- ==========================================
-- INDEXES (IMPORTANT FOR PERFORMANCE)
-- ==========================================

CREATE INDEX idx_exercises_user
ON exercises(user_created_by);

CREATE INDEX idx_exercises_video
ON exercises(video_id);

CREATE INDEX idx_trainings_user
ON trainings(user_created_by);

CREATE INDEX idx_training_exercises_training
ON training_exercises(training_id);

CREATE INDEX idx_training_exercises_exercise
ON training_exercises(exercise_id);