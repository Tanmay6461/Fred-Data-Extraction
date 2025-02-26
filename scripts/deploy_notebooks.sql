--!jinja

CREATE OR REPLACE NOTEBOOK IDENTIFIER('"FRED_DB"."{{env}}_INTEGRATIONS"."{{env}}_DB_OBJECTS"')
    FROM '@"FRED_DB"."INTEGRATIONS"."GIT_REPO"/branches/"{{branch}}"/notebooks/'
    QUERY_WAREHOUSE = 'FRED_WH'
    MAIN_FILE = 'DB_OBJECTS.ipynb';

ALTER NOTEBOOK "FRED_DB"."{{env}}_INTEGRATIONS"."{{env}}_DB_OBJECTS" ADD LIVE VERSION FROM LAST;

EXECUTE NOTEBOOK "FRED_DB"."{{env}}_INTEGRATIONS"."{{env}}_DB_OBJECTS"();
