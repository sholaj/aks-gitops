-- MS SQL Server Database Setup Script
-- Creates test_db database and test_user with appropriate permissions

USE master;
GO

-- Create the test database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'test_db')
BEGIN
    CREATE DATABASE test_db;
    PRINT 'Database test_db created successfully';
END
ELSE
BEGIN
    PRINT 'Database test_db already exists';
END
GO

-- Use the test database
USE test_db;
GO

-- Create a login at server level
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'test_user')
BEGIN
    CREATE LOGIN test_user WITH PASSWORD = 'P@ssw0rd';
    PRINT 'Login test_user created successfully';
END
ELSE
BEGIN
    PRINT 'Login test_user already exists';
END
GO

-- Create a user in the test_db database
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'test_user')
BEGIN
    CREATE USER test_user FOR LOGIN test_user;
    PRINT 'User test_user created successfully in test_db';
END
ELSE
BEGIN
    PRINT 'User test_user already exists in test_db';
END
GO

-- Grant necessary permissions for compliance scanning
-- Grant read permissions on system views for compliance checks
ALTER ROLE db_datareader ADD MEMBER test_user;
GO

-- Grant view server state permission (needed for some compliance checks)
USE master;
GO
GRANT VIEW SERVER STATE TO test_user;
GO

-- Grant view any definition (needed to view database configurations)
GRANT VIEW ANY DEFINITION TO test_user;
GO

-- Create a sample table for testing
USE test_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'sample_table')
BEGIN
    CREATE TABLE sample_table (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(50) NOT NULL,
        email NVARCHAR(100),
        created_date DATETIME DEFAULT GETDATE()
    );
    
    -- Insert sample data
    INSERT INTO sample_table (name, email) VALUES 
    ('John Doe', 'john.doe@example.com'),
    ('Jane Smith', 'jane.smith@example.com');
    
    PRINT 'Sample table created and populated';
END
ELSE
BEGIN
    PRINT 'Sample table already exists';
END
GO

-- Display configuration information for verification
PRINT 'Database setup completed. Configuration summary:';
PRINT '================================================';

SELECT 
    'Database' as Item,
    name as Value
FROM sys.databases 
WHERE name = 'test_db';

SELECT 
    'User Login' as Item,
    name as Value
FROM sys.server_principals 
WHERE name = 'test_user';

-- Check password policy (this requires VIEW SERVER STATE permission)
SELECT 
    'Password Policy Check' as Item,
    CASE 
        WHEN is_policy_checked = 1 THEN 'Password policy enforced'
        ELSE 'Password policy not enforced'
    END as Value
FROM sys.sql_logins 
WHERE name = 'test_user';

PRINT 'Setup script execution completed.';