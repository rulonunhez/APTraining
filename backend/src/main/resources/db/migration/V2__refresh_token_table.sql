CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token VARCHAR(255) NOT NULL UNIQUE,
    user_id UUID NOT NULL,
    expiry_date TIMESTAMP NOT NULL,
    device_info VARCHAR(255)
);