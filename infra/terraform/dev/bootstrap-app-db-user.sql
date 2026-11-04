-- Run with psql as aptraining_admin against database aptraining.
-- Set APTRAINING_APP_DB_PASSWORD in the process environment first; never commit it.
\getenv app_password APTRAINING_APP_DB_PASSWORD

SELECT COALESCE(length(:'app_password') > 0, false) AS app_password_set \gset
\if :app_password_set
\else
  \echo "APTRAINING_APP_DB_PASSWORD must be set to a non-empty value"
  \quit 3
\endif

SELECT format('CREATE ROLE aptraining_app LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aptraining_app')
\gexec

ALTER ROLE aptraining_app LOGIN PASSWORD :'app_password';
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
GRANT CONNECT ON DATABASE aptraining TO aptraining_app;
GRANT USAGE, CREATE ON SCHEMA public TO aptraining_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO aptraining_app;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO aptraining_app;

-- Install uuid-ossp as the master user so the app role does not need CREATE on
-- the database. Flyway's matching migration will then see the extension exists.
-- Future Flyway objects are owned by aptraining_app, so no default grants are needed.
