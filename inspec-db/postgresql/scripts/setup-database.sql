-- PostgreSQL Database Setup Script
-- Creates test_db database and test_user with appropriate permissions

-- Connect as postgres superuser
\c postgres;

-- Create the test database
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'test_db') THEN
        PERFORM dblink_exec('dbname=postgres', 'CREATE DATABASE test_db');
        RAISE NOTICE 'Database test_db created successfully';
    ELSE
        RAISE NOTICE 'Database test_db already exists';
    END IF;
END
$$;

-- Alternative approach using CREATE DATABASE with conditional logic
SELECT 'CREATE DATABASE test_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'test_db')\gexec

-- Create user with password
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_user WHERE usename = 'test_user') THEN
        CREATE USER test_user WITH PASSWORD 'P@ssw0rd';
        RAISE NOTICE 'User test_user created successfully';
    ELSE
        RAISE NOTICE 'User test_user already exists';
        -- Update password in case it needs to be reset
        ALTER USER test_user WITH PASSWORD 'P@ssw0rd';
        RAISE NOTICE 'User test_user password updated';
    END IF;
END
$$;

-- Grant database permissions to test_user
GRANT CONNECT ON DATABASE test_db TO test_user;
GRANT USAGE ON SCHEMA public TO test_user;
GRANT CREATE ON SCHEMA public TO test_user;

-- Connect to the test database
\c test_db;

-- Grant additional permissions in the test database
GRANT ALL PRIVILEGES ON DATABASE test_db TO test_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO test_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO test_user;

-- Create a sample table for testing
CREATE TABLE IF NOT EXISTS sample_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO sample_table (name, email) 
SELECT 'John Doe', 'john.doe@example.com'
WHERE NOT EXISTS (SELECT 1 FROM sample_table WHERE name = 'John Doe');

INSERT INTO sample_table (name, email) 
SELECT 'Jane Smith', 'jane.smith@example.com'
WHERE NOT EXISTS (SELECT 1 FROM sample_table WHERE name = 'Jane Smith');

-- Grant specific table permissions to test_user
GRANT ALL PRIVILEGES ON TABLE sample_table TO test_user;
GRANT ALL PRIVILEGES ON SEQUENCE sample_table_id_seq TO test_user;

-- Create a view for compliance checking
CREATE OR REPLACE VIEW ssl_status AS
SELECT 
    CASE 
        WHEN setting = 'on' THEN 'SSL enabled'
        ELSE 'SSL disabled'
    END AS ssl_configuration
FROM pg_settings 
WHERE name = 'ssl';

-- Grant access to the view
GRANT SELECT ON ssl_status TO test_user;

-- Grant necessary system permissions for compliance scanning
-- These permissions allow the test_user to query system catalogs for compliance checks
GRANT SELECT ON pg_settings TO test_user;
GRANT SELECT ON pg_authid TO test_user;
GRANT SELECT ON pg_user TO test_user;
GRANT SELECT ON pg_shadow TO test_user;
GRANT SELECT ON information_schema.tables TO test_user;
GRANT SELECT ON information_schema.columns TO test_user;

-- Connect back to postgres database to set additional permissions
\c postgres;

-- Grant access to system catalogs across databases
GRANT SELECT ON pg_authid TO test_user;
GRANT SELECT ON pg_settings TO test_user;

-- Create a function to check password policies (PostgreSQL doesn't have built-in password policies like SQL Server)
CREATE OR REPLACE FUNCTION check_password_policy(username text)
RETURNS TABLE(
    user_name text,
    password_set boolean,
    account_locked boolean,
    connection_limit integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rolname::text,
        rolpassword IS NOT NULL,
        NOT rolcanlogin,
        rolconnlimit
    FROM pg_authid
    WHERE rolname = username;
END;
$$ LANGUAGE plpgsql;

-- Grant execution permission on the function
GRANT EXECUTE ON FUNCTION check_password_policy(text) TO test_user;

-- Display configuration summary
\echo ''
\echo 'Database setup completed. Configuration summary:'
\echo '==============================================='

-- Show database information
SELECT 'Database' as item, datname as value 
FROM pg_database 
WHERE datname = 'test_db';

-- Show user information
SELECT 'User' as item, usename as value 
FROM pg_user 
WHERE usename = 'test_user';

-- Show SSL configuration
SELECT 'SSL Configuration' as item, setting as value 
FROM pg_settings 
WHERE name = 'ssl';

-- Show sample table record count
\c test_db;
SELECT 'Sample Table Records' as item, COUNT(*)::text as value 
FROM sample_table;

\echo ''
\echo 'Setup script execution completed.'
\echo 'Test connection: psql -h localhost -U test_user -d test_db'