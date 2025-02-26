USE ROLE FRED_ROLE;
USE WAREHOUSE FRED_WH;
USE SCHEMA  FRED_DB.FRED_HARMONIZED;

CREATE OR REPLACE TASK FRED_DB.FRED_HARMONIZED.DATA_UPDATE_TASK
WAREHOUSE = FRED_WH
WHEN 
    SYSTEM$STREAM_HAS_DATA('FRED_DB.FRED_RAW.FRED_RAW_STAGE_STREAM')
AS 
CALL FRED_HARMONIZED.FRED_DATA_UPDATE_SP();


use role accountadmin;
GRANT USAGE ON WAREHOUSE FRED_WH TO ROLE FRED_ROLE;
GRANT USAGE ON SCHEMA FRED_DB.FRED_HARMONIZED TO ROLE FRED_ROLE;
GRANT EXECUTE ON PROCEDURE FRED_DB.FRED_HARMONIZED.FRED_DATA_UPDATE_SP TO ROLE FRED_ROLE;
GRANT SELECT ON STREAM FRED_DB.FRED_RAW.FRED_RAW_STAGE_STREAM TO ROLE FRED_ROLE;


-- drop task DATA_UPDATE_TASK;

EXECUTE TASK DATA_UPDATE_TASK;

-- Start the task manually (if needed for testing)
ALTER TASK DATA_UPDATE_TASK RESUME;
