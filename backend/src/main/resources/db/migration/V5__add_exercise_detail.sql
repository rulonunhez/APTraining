-- =========================
-- MUSCLE GROUPS
-- =========================
CREATE TABLE muscle_groups (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL
);

INSERT INTO muscle_groups (code, name) VALUES
('CHEST', 'Pecho'),
('BACK', 'Espalda'),
('SHOULDERS', 'Hombros'),
('BICEPS', 'Biceps'),
('TRICEPS', 'Triceps'),
('FOREARMS', 'Antebrazos'),
('QUADRICEPS', 'Cuadriceps'),
('HAMSTRINGS', 'Isquiotibiales'),
('GLUTES', 'Gluteos'),
('CALVES', 'Gemelos'),
('CORE', 'Core'),
('LOWER_BACK', 'Lumbar'),
('FULL_BODY', 'Cuerpo completo');

-- =========================
-- EXERCISE TYPES
-- =========================
CREATE TABLE exercise_types (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL
);

INSERT INTO exercise_types (code, name) VALUES
('STRENGTH', 'Fuerza'),
('HYPERTROPHY', 'Hipertrofia'),
('ENDURANCE', 'Resistencia'),
('POWER', 'Potencia'),
('MOBILITY', 'Movilidad'),
('CARDIO', 'Cardio'),
('TECHNIQUE', 'Tecnica');

-- =========================
-- MOVEMENT PATTERNS
-- =========================
CREATE TABLE movement_patterns (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL
);

INSERT INTO movement_patterns (code, name) VALUES
('PUSH', 'Empuje'),
('PULL', 'Traccion'),
('SQUAT', 'Sentadilla'),
('HIP_HINGE', 'Bisagra de cadera'),
('LUNGE', 'Zancada'),
('CARRY', 'Carga'),
('ROTATION', 'Rotacion'),
('ANTI_ROTATION', 'Anti-rotacion'),
('GAIT', 'Marcha');

-- =========================
-- EQUIPMENT
-- =========================
CREATE TABLE equipment (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL
);

INSERT INTO equipment (code, name) VALUES
('BARBELL', 'Barra'),
('DUMBBELL', 'Mancuernas'),
('KETTLEBELL', 'Kettlebell'),
('MACHINE', 'Maquina'),
('CABLE', 'Polea'),
('BAND', 'Banda elastica'),
('BODYWEIGHT', 'Peso corporal'),
('TRX', 'TRX'),
('MEDICINE_BALL', 'Balon medicinal'),
('SMITH_MACHINE', 'Multipower'),
('TRAP_BAR', 'Barra hexagonal'),
('EZ_BAR', 'Barra Z');

-- =========================
-- RELACIONES
-- =========================

CREATE TABLE exercise_primary_muscle_groups (
    exercise_id UUID REFERENCES exercises(id) ON DELETE CASCADE,
    muscle_group_id BIGINT REFERENCES muscle_groups(id),
    PRIMARY KEY (exercise_id, muscle_group_id)
);

CREATE TABLE exercise_secondary_muscle_groups (
    exercise_id UUID REFERENCES exercises(id) ON DELETE CASCADE,
    muscle_group_id BIGINT REFERENCES muscle_groups(id),
    PRIMARY KEY (exercise_id, muscle_group_id)
);

CREATE TABLE exercise_equipment (
    exercise_id UUID REFERENCES exercises(id) ON DELETE CASCADE,
    equipment_id BIGINT REFERENCES equipment(id),
    PRIMARY KEY (exercise_id, equipment_id)
);

-- =========================
-- NUEVAS COLUMNAS
-- =========================

ALTER TABLE exercises
ADD COLUMN exercise_type_id BIGINT REFERENCES exercise_types(id),
ADD COLUMN movement_pattern_id BIGINT REFERENCES movement_patterns(id),
ADD COLUMN explanation TEXT,
ADD COLUMN tips TEXT,
ADD COLUMN common_mistakes TEXT;