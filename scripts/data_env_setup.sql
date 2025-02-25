-- Project Initialization for Production Environment Setup
--
-- This script establishes the foundational environment necessary for deploying the project
-- into the production environment. The following steps will be executed:
-- Note: This script can call a notebook with Snowpark integration, but most operations can be performed using SQL
-- with CREATE OR REPLACE commands, except for step (3)
-- 1. Create a user role and grant appropriate permissions.
-- 2. Use the created role to set up essential database objects, including:
--    2.1. Configure GIT API Integration.
--    2.2. Create Database, Schemas, and Warehouse.
--    2.3. Set up External/Internal Stages if necessary.
--    2.4. Create Permanent Tables under appropriate schemas (RAW/HARMONIZED/ANALYTICS).
--    2.5. Define User Defined Functions (UDFs).
--    2.6. Develop Stored Procedures.
--    2.7. Implement Streams on appropriate schemas.
--    2.8. Create Materialized Views in the ANALYTICS schema.
--    2.9. Define and schedule Tasks for automation.
-- 3. Load data upto current date
 

SET GITHUB_SECRET_USERNAME = {{GITHUB_SECRET_USERNAME}};
SET GITHUB_SECRET_PASSWORD = {{GITHUB_SECRET_PASSWORD}};
SET GITHUB_URL_PREFIX = 'https://github.com/bigdata-org';
SET GITHUB_REPO_ORIGIN = 'https://github.com/bigdata-org/fred_data_extraction.git';
SET AWS_ACCESS_KEY = {{AWS_ACCESS_KEY}};
SET AWS_SECRET_ACCESS_KEY = {{AWS_SECRET_ACCESS_KEY}};
SET AWS_CREDENTIALS = '{"AWS_ACCESS_KEY":"' || $AWS_ACCESS_KEY || '", "AWS_SECRET_ACCESS_KEY":"' || $AWS_SECRET_ACCESS_KEY || '"}';
 
USE ROLE FRED_ROLE;
--DATABASE
CREATE OR REPLACE DATABASE FRED_DB;
 
--WAREHOUSE
CREATE OR REPLACE WAREHOUSE FRED_WH WAREHOUSE_SIZE = XSMALL, AUTO_SUSPEND = 300, AUTO_RESUME= TRUE;
 
USE WAREHOUSE FRED_WH;
USE DATABASE FRED_DB;

--SCHEMA
CREATE OR REPLACE SCHEMA "FRED_DB"."{{env}}_OBJECTS"; 
CREATE OR REPLACE SCHEMA "FRED_DB"."{{env}}_FRED_RAW";
CREATE OR REPLACE SCHEMA "FRED_DB"."{{env}}_FRED_HARMONIZED";
CREATE OR REPLACE SCHEMA "FRED_DB"."{{env}}_FRED_ANALYTICS";
 
-- file format (schema level)
CREATE OR REPLACE FILE FORMAT "FRED_DB"."{{env}}_OBJECTS".CSV_FILE_FORMAT
    TYPE = CSV
    SKIP_HEADER=1;


CREATE OR REPLACE STAGE "FRED_DB"."{{env}}_OBJECTS".FRED_RAW_STAGE
    URL = 's3://sfopenaccessbucket/'
    FILE_FORMAT = "FRED_DB"."{{env}}_OBJECTS".CSV_FILE_FORMAT
    CREDENTIALS = (AWS_KEY_ID = $AWS_ACCESS_KEY 
                   AWS_SECRET_KEY = $AWS_SECRET_ACCESS_KEY);

 
-- Secrets (schema level)
CREATE OR REPLACE SECRET "FRED_DB"."{{env}}_OBJECTS".GITHUB_SECRET
  TYPE = password
  USERNAME = $GITHUB_SECRET_USERNAME
  PASSWORD = $GITHUB_SECRET_PASSWORD;

CREATE OR REPLACE SECRET "FRED_DB"."{{env}}_OBJECTS".AWS_S3_SECRET
TYPE = GENERIC_STRING 
SECRET_STRING = $AWS_CREDENTIALS;

-- API Integration (account level)
-- This depends on the schema level secret
CREATE OR REPLACE API INTEGRATION GITHUB_API_INTEGRATION
  API_PROVIDER = GIT_HTTPS_API
  API_ALLOWED_PREFIXES = ($GITHUB_URL_PREFIX)
  ALLOWED_AUTHENTICATION_SECRETS = ("FRED_DB"."{{env}}_OBJECTS".GITHUB_SECRET)
  ENABLED = TRUE;
   
-- Git Repository
CREATE OR REPLACE GIT REPOSITORY "FRED_DB"."{{env}}_OBJECTS".GIT_REPO
  API_INTEGRATION = GITHUB_API_INTEGRATION
  GIT_CREDENTIALS = "FRED_DB"."{{env}}_OBJECTS".GITHUB_SECRET
  ORIGIN = $GITHUB_REPO_ORIGIN;

--Permanent Table Configuration
CREATE OR REPLACE TABLE "FRED_DB"."{{env}}_FRED_RAW".FREDDATA (DATA_DATE DATE, VALUE NUMBER(5,2));
CREATE OR REPLACE STREAM "FRED_DB"."{{env}}_FRED_RAW".FREDDATA_STREAM ON TABLE "FRED_DB"."{{env}}_FRED_RAW".FREDDATA;

CREATE OR REPLACE TABLE "FRED_DB"."{{env}}_FRED_HARMONIZED".FREDDATA (DATA_DATE DATE, VALUE NUMBER(5,2), CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE MATERIALIZED VIEW "FRED_DB"."{{env}}_FRED_ANALYTICS".FREDDATA 
AS SELECT DATA_DATE, VALUE FROM "FRED_DB"."{{env}}_FRED_HARMONIZED".FREDDATA;


-- Network Configuration
CREATE OR REPLACE NETWORK RULE FREDAPI_NR
 MODE = EGRESS
 TYPE = HOST_PORT 
 VALUE_LIST = ('api.stlouisfed.org');

 -- make access integration , doesnt work on trial ccounts:
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION FREDAPI_EXT_ACCESS_INT
 ALLOWED_NETWORK_RULES = (FREDAPI_NR)
 ALLOWED_AUTHENTICATION_SECRETS = ("FRED_DB"."{{env}}_OBJECTS".AWS_S3_SECRET)
 ENABLED = true;

 CREATE OR REPLACE NETWORK RULE S3_NR
 MODE = EGRESS
 TYPE = HOST_PORT 
 VALUE_LIST = ('sfopenaccessbucket.s3.amazonaws.com');

 -- make access integration , doesnt work on trial ccounts:
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION S3_EXT_ACCESS_INT
 ALLOWED_NETWORK_RULES = (S3_NR)
 ENABLED = true;

 
CREATE OR REPLACE FUNCTION "FRED_DB"."{{env}}_OBJECTS".fredapi_response_to_df(api_url STRING)
RETURNS INTEGER
LANGUAGE PYTHON
RUNTIME_VERSION = 3.9
EXTERNAL_ACCESS_INTEGRATIONS = (FREDAPI_EXT_ACCESS_INT, S3_EXT_ACCESS_INT) -- Make sure this integration is set up for AWS
HANDLER = 'fredapi_response_to_df'
PACKAGES = ('requests', 'pandas', 'boto3')
SECRETS = ('AWS_S3_SECRET' = "FRED_DB"."{{env}}_OBJECTS".AWS_S3_SECRET)   -- Added boto3 for AWS S3 interaction
AS
$$
import _snowflake
import requests
import pandas as pd
import boto3
from io import StringIO

def fredapi_response_to_df(api_url):
    try:
        secrets = _snowflake.get_generic_secret_string("AWS_S3_SECRET")
        secrets = eval(secrets)
        aws_access_key_id = secrets["AWS_ACCESS_KEY"]
        aws_secret_access_key = secrets["AWS_SECRET_ACCESS_KEY"]
        # Fetch the data from the API
        response = requests.get(api_url)
        data = response.json()
        
        # Create DataFrame and process data
        df = pd.DataFrame(data['observations'])
        df.drop(columns=['realtime_start', 'realtime_end'], inplace=True)

        # Convert DataFrame to CSV
        csv_data = StringIO()
        df.to_csv(csv_data, index=False)

        # Upload to AWS S3
        bucket_name = 'sfopenaccessbucket'  # Your S3 bucket name
        s3_key = 'fred/data.csv'  # Path within the S3 bucket
        
        s3_client = boto3.client(
            's3',
            region_name='us-east-1',
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key
        )
        s3_client.put_object(Bucket=bucket_name, Key=s3_key, Body=csv_data.getvalue(), ContentType='text/csv')

    except Exception as e:
        return 0
    return 1  # Return success message
$$;