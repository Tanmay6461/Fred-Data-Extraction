-- run from accountadmin or sysadmin
-- minimal privs necessary for the creation of user environment

CREATE OR REPLACE ROLE  FRED_ROLE;
GRANT ROLE FRED_ROLE TO USER DBT_DEV;
GRANT ROLE FRED_ROLE TO ROLE SYSADMIN;
create or replace database FRED_SETUP;
create or replace schema DBO;
grant ownership on database fred_setup to role FRED_ROLE;
grant ownership on schema fred_setup.DBO to role FRED_ROLE;

GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE FRED_ROLE;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE FRED_ROLE;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE FRED_ROLE;
GRANT MONITOR EXECUTION ON ACCOUNT TO ROLE FRED_ROLE;
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE FRED_ROLE;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE FRED_ROLE;

