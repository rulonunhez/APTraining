-- Roles: permitir TRAINER (entrenador)
ALTER TABLE users DROP CONSTRAINT chk_users_role;
ALTER TABLE users
    ADD CONSTRAINT chk_users_role
        CHECK (role IS NULL OR role IN ('USER', 'ADMIN', 'TRAINER'));

-- Grupos de usuarios: herramienta visual de seleccion para entrenadores.
-- No tienen efecto vivo sobre las asignaciones (ver training_plan_assignments).
CREATE TABLE user_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by UUID NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_groups_creator FOREIGN KEY (created_by)
        REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE user_group_members (
    group_id UUID NOT NULL,
    user_id UUID NOT NULL,
    PRIMARY KEY (group_id, user_id),
    CONSTRAINT fk_user_group_members_group FOREIGN KEY (group_id)
        REFERENCES user_groups(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_group_members_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_user_groups_creator ON user_groups(created_by);
CREATE INDEX idx_user_group_members_user ON user_group_members(user_id);

-- Asignaciones individuales de planificaciones.
-- Los grupos se expanden a usuarios al guardar el plan; source_group_id
-- solo es informativo para permitir una sincronizacion posterior explicita.
CREATE TABLE training_plan_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID NOT NULL,
    user_id UUID NOT NULL,
    assigned_by UUID NOT NULL,
    source_group_id UUID,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_training_plan_assignments_plan_user UNIQUE (plan_id, user_id),
    CONSTRAINT fk_tpa_plan FOREIGN KEY (plan_id)
        REFERENCES training_plans(id) ON DELETE CASCADE,
    CONSTRAINT fk_tpa_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_tpa_assigned_by FOREIGN KEY (assigned_by)
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_tpa_source_group FOREIGN KEY (source_group_id)
        REFERENCES user_groups(id) ON DELETE SET NULL
);

CREATE INDEX idx_tpa_user ON training_plan_assignments(user_id);
CREATE INDEX idx_tpa_source_group ON training_plan_assignments(source_group_id);
