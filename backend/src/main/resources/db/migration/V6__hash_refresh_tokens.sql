DELETE FROM refresh_tokens;

ALTER TABLE refresh_tokens DROP COLUMN token;
ALTER TABLE refresh_tokens ADD COLUMN token_hash VARCHAR(64) NOT NULL UNIQUE;