
    -- ========================================================================
    -- Healthcare AI Demo - Complete Setup Script
    -- Grady Health System - Denial Management Intelligence
    -- This script creates the database, schema, tables, and loads all data
    -- Repository: https://github.com/YOUR_ORG/Healthcare_AI_DEMO.git
    -- ========================================================================


    -- Switch to accountadmin role
    USE ROLE ACCOUNTADMIN;

    -- Create demo role
    CREATE OR REPLACE ROLE HEALTHCARE_AI_DEMO;

    SET current_user_name = CURRENT_USER();
    GRANT ROLE HEALTHCARE_AI_DEMO TO USER IDENTIFIER($current_user_name);
    GRANT CREATE DATABASE ON ACCOUNT TO ROLE HEALTHCARE_AI_DEMO;

    -- Create warehouse
    CREATE OR REPLACE WAREHOUSE HEALTHCARE_DEMO_WH
        WITH WAREHOUSE_SIZE = 'XSMALL'
        AUTO_SUSPEND = 300
        AUTO_RESUME = TRUE;

    GRANT USAGE ON WAREHOUSE HEALTHCARE_DEMO_WH TO ROLE HEALTHCARE_AI_DEMO;

    ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_ROLE = HEALTHCARE_AI_DEMO;
    ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_WAREHOUSE = HEALTHCARE_DEMO_WH;

    USE ROLE HEALTHCARE_AI_DEMO;

    -- Create database and schema
    CREATE OR REPLACE DATABASE HEALTHCARE_AI_DEMO;
    USE DATABASE HEALTHCARE_AI_DEMO;
    CREATE SCHEMA IF NOT EXISTS DENIALS;
    USE SCHEMA DENIALS;

    -- CSV file format
    CREATE OR REPLACE FILE FORMAT CSV_FORMAT
        TYPE = 'CSV'
        FIELD_DELIMITER = ','
        RECORD_DELIMITER = '\n'
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        TRIM_SPACE = TRUE
        ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        ESCAPE = 'NONE'
        ESCAPE_UNENCLOSED_FIELD = '\134'
        DATE_FORMAT = 'YYYY-MM-DD'
        TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'
        NULL_IF = ('NULL', 'null', '', 'N/A', 'n/a');


    -- ========================================================================
    -- GIT INTEGRATION
    -- ========================================================================

    USE ROLE ACCOUNTADMIN;

    -- TODO: Update API_ALLOWED_PREFIXES with your GitHub org URL
    CREATE OR REPLACE API INTEGRATION git_api_integration
        API_PROVIDER = git_https_api
        API_ALLOWED_PREFIXES = ('https://github.com/YOUR_ORG/')
        ENABLED = TRUE;

    GRANT USAGE ON INTEGRATION GIT_API_INTEGRATION TO ROLE HEALTHCARE_AI_DEMO;

    USE ROLE HEALTHCARE_AI_DEMO;

    -- TODO: Update ORIGIN with your repository URL
    CREATE OR REPLACE GIT REPOSITORY HEALTHCARE_AI_DEMO_REPO
        API_INTEGRATION = git_api_integration
        ORIGIN = 'https://github.com/YOUR_ORG/Healthcare_AI_DEMO.git';

    -- Internal stage for data files
    CREATE OR REPLACE STAGE INTERNAL_DATA_STAGE
        FILE_FORMAT = CSV_FORMAT
        COMMENT = 'Internal stage for healthcare demo data'
        DIRECTORY = (ENABLE = TRUE)
        ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

    ALTER GIT REPOSITORY HEALTHCARE_AI_DEMO_REPO FETCH;

    -- ========================================================================
    -- COPY DATA FROM GIT TO INTERNAL STAGE
    -- ========================================================================

    COPY FILES
    INTO @INTERNAL_DATA_STAGE/demo_data/
    FROM @HEALTHCARE_AI_DEMO_REPO/branches/main/demo_data/;

    COPY FILES
    INTO @INTERNAL_DATA_STAGE/unstructured_docs/
    FROM @HEALTHCARE_AI_DEMO_REPO/branches/main/unstructured_docs/;

    LS @INTERNAL_DATA_STAGE;
    ALTER STAGE INTERNAL_DATA_STAGE REFRESH;


    -- ========================================================================
    -- DIMENSION TABLES
    -- ========================================================================

    CREATE OR REPLACE TABLE payer_dim (
        payer_key INT PRIMARY KEY,
        payer_name VARCHAR(200) NOT NULL,
        payer_type VARCHAR(50) NOT NULL
    );

    CREATE OR REPLACE TABLE facility_dim (
        facility_key INT PRIMARY KEY,
        facility_name VARCHAR(200) NOT NULL,
        facility_type VARCHAR(100),
        care_setting VARCHAR(50),
        address VARCHAR(200),
        city VARCHAR(100),
        state VARCHAR(10),
        zip VARCHAR(20)
    );

    CREATE OR REPLACE TABLE department_dim (
        department_key INT PRIMARY KEY,
        department_name VARCHAR(100) NOT NULL
    );

    CREATE OR REPLACE TABLE provider_dim (
        provider_key INT PRIMARY KEY,
        provider_name VARCHAR(200) NOT NULL,
        npi VARCHAR(20),
        department_key INT
    );

    CREATE OR REPLACE TABLE procedure_dim (
        procedure_key INT PRIMARY KEY,
        cpt_code VARCHAR(10) NOT NULL,
        procedure_description VARCHAR(300) NOT NULL,
        procedure_category VARCHAR(100),
        standard_charge DECIMAL(10,2)
    );

    CREATE OR REPLACE TABLE denial_reason_dim (
        denial_reason_key INT PRIMARY KEY,
        denial_reason_code VARCHAR(20) NOT NULL,
        denial_reason_description VARCHAR(300) NOT NULL,
        denial_category VARCHAR(100),
        denial_subcategory VARCHAR(100)
    );

    CREATE OR REPLACE TABLE appeal_status_dim (
        appeal_status_key INT PRIMARY KEY,
        appeal_status VARCHAR(50) NOT NULL,
        appeal_status_description VARCHAR(200)
    );

    CREATE OR REPLACE TABLE date_dim (
        date_key INT PRIMARY KEY,
        full_date DATE NOT NULL,
        year INT,
        month_num INT,
        month_name VARCHAR(20),
        quarter VARCHAR(5),
        day_of_week VARCHAR(20),
        week_of_year INT
    );


    -- ========================================================================
    -- FACT TABLES
    -- ========================================================================

    CREATE OR REPLACE TABLE denial_claims_fact (
        claim_id INT PRIMARY KEY,
        patient_id VARCHAR(20),
        date_of_service DATE NOT NULL,
        denial_date DATE NOT NULL,
        payer_key INT NOT NULL,
        procedure_key INT NOT NULL,
        department_key INT NOT NULL,
        facility_key INT NOT NULL,
        provider_key INT NOT NULL,
        denial_reason_key INT NOT NULL,
        appeal_status_key INT NOT NULL,
        claim_amount DECIMAL(12,2) NOT NULL,
        denied_amount DECIMAL(12,2) NOT NULL,
        days_to_resolution INT
    );

    CREATE OR REPLACE TABLE appeals_fact (
        appeal_id INT PRIMARY KEY,
        claim_id INT NOT NULL,
        appeal_filed_date DATE NOT NULL,
        appeal_level INT,
        appeal_level_name VARCHAR(50),
        appeal_status_key INT NOT NULL,
        denied_amount DECIMAL(12,2),
        recovered_amount DECIMAL(12,2)
    );

    CREATE OR REPLACE TABLE monthly_denial_summary (
        summary_id INT PRIMARY KEY,
        year INT NOT NULL,
        month INT NOT NULL,
        payer_key INT NOT NULL,
        total_denials INT,
        total_charges DECIMAL(14,2),
        total_denied_amount DECIMAL(14,2),
        total_appealed INT,
        total_overturned INT
    );


    -- ========================================================================
    -- LOAD DIMENSION DATA
    -- ========================================================================

    COPY INTO payer_dim FROM @INTERNAL_DATA_STAGE/demo_data/payer_dim.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

    COPY INTO facility_dim FROM @INTERNAL_DATA_STAGE/demo_data/facility_dim.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

    COPY INTO department_dim FROM @INTERNAL_DATA_STAGE/demo_data/department_dim.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

    COPY INTO provider_dim FROM @INTERNAL_DATA_STAGE/demo_data/provider_dim.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

    COPY INTO procedure_dim FROM @INTERNAL_DATA_STAGE/demo_data/procedure_dim.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

    COPY INTO denial_reason_dim FROM @INTERNAL_DATA_STAGE/demo_data/denial_reason_dim.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

    COPY INTO appeal_status_dim FROM @INTERNAL_DATA_STAGE/demo_data/appeal_status_dim.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

    COPY INTO date_dim FROM @INTERNAL_DATA_STAGE/demo_data/date_dim.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';


    -- ========================================================================
    -- LOAD FACT DATA
    -- ========================================================================

    COPY INTO denial_claims_fact FROM @INTERNAL_DATA_STAGE/demo_data/denial_claims_fact.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

    COPY INTO appeals_fact FROM @INTERNAL_DATA_STAGE/demo_data/appeals_fact.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';

    COPY INTO monthly_denial_summary FROM @INTERNAL_DATA_STAGE/demo_data/monthly_denial_summary.csv
    FILE_FORMAT = CSV_FORMAT ON_ERROR = 'CONTINUE';


    -- ========================================================================
    -- VERIFICATION
    -- ========================================================================

    SELECT 'DIMENSION TABLES' AS category, '' AS table_name, NULL AS row_count
    UNION ALL SELECT '', 'payer_dim', COUNT(*) FROM payer_dim
    UNION ALL SELECT '', 'facility_dim', COUNT(*) FROM facility_dim
    UNION ALL SELECT '', 'department_dim', COUNT(*) FROM department_dim
    UNION ALL SELECT '', 'provider_dim', COUNT(*) FROM provider_dim
    UNION ALL SELECT '', 'procedure_dim', COUNT(*) FROM procedure_dim
    UNION ALL SELECT '', 'denial_reason_dim', COUNT(*) FROM denial_reason_dim
    UNION ALL SELECT '', 'appeal_status_dim', COUNT(*) FROM appeal_status_dim
    UNION ALL SELECT '', 'date_dim', COUNT(*) FROM date_dim
    UNION ALL SELECT '', '', NULL
    UNION ALL SELECT 'FACT TABLES', '', NULL
    UNION ALL SELECT '', 'denial_claims_fact', COUNT(*) FROM denial_claims_fact
    UNION ALL SELECT '', 'appeals_fact', COUNT(*) FROM appeals_fact
    UNION ALL SELECT '', 'monthly_denial_summary', COUNT(*) FROM monthly_denial_summary;

    SHOW TABLES IN SCHEMA DENIALS;


    -- ========================================================================
    -- SEMANTIC VIEW: DENIAL ANALYTICS
    -- ========================================================================

    USE ROLE HEALTHCARE_AI_DEMO;
    USE DATABASE HEALTHCARE_AI_DEMO;
    USE SCHEMA DENIALS;

    CREATE OR REPLACE SEMANTIC VIEW HEALTHCARE_AI_DEMO.DENIALS.DENIAL_ANALYTICS_SV
      TABLES (
        CLAIMS AS DENIAL_CLAIMS_FACT PRIMARY KEY (CLAIM_ID)
          WITH SYNONYMS=('denials','denied claims','claim denials')
          COMMENT='Fact table of all denied claims with financial and resolution data',
        PAYERS AS PAYER_DIM PRIMARY KEY (PAYER_KEY)
          WITH SYNONYMS=('insurance companies','health plans','payers')
          COMMENT='Insurance payer dimension',
        PROCEDURES AS PROCEDURE_DIM PRIMARY KEY (PROCEDURE_KEY)
          WITH SYNONYMS=('CPT codes','medical procedures','services')
          COMMENT='Medical procedure and CPT code dimension',
        DEPARTMENTS AS DEPARTMENT_DIM PRIMARY KEY (DEPARTMENT_KEY)
          WITH SYNONYMS=('clinical departments','specialties')
          COMMENT='Hospital department dimension',
        FACILITIES AS FACILITY_DIM PRIMARY KEY (FACILITY_KEY)
          WITH SYNONYMS=('locations','sites','hospitals','clinics')
          COMMENT='Facility and care setting dimension',
        DENIAL_REASONS AS DENIAL_REASON_DIM PRIMARY KEY (DENIAL_REASON_KEY)
          WITH SYNONYMS=('reason codes','CARC codes','denial codes')
          COMMENT='Claim Adjustment Reason Code (CARC) dimension',
        APPEAL_STATUSES AS APPEAL_STATUS_DIM PRIMARY KEY (APPEAL_STATUS_KEY)
          WITH SYNONYMS=('appeal outcomes','appeal results')
          COMMENT='Appeal status and outcome dimension',
        PROVIDERS AS PROVIDER_DIM PRIMARY KEY (PROVIDER_KEY)
          WITH SYNONYMS=('doctors','physicians','rendering providers')
          COMMENT='Rendering provider dimension'
      )
      RELATIONSHIPS (
        CLAIMS_TO_PAYERS AS CLAIMS(PAYER_KEY) REFERENCES PAYERS(PAYER_KEY),
        CLAIMS_TO_PROCEDURES AS CLAIMS(PROCEDURE_KEY) REFERENCES PROCEDURES(PROCEDURE_KEY),
        CLAIMS_TO_DEPARTMENTS AS CLAIMS(DEPARTMENT_KEY) REFERENCES DEPARTMENTS(DEPARTMENT_KEY),
        CLAIMS_TO_FACILITIES AS CLAIMS(FACILITY_KEY) REFERENCES FACILITIES(FACILITY_KEY),
        CLAIMS_TO_REASONS AS CLAIMS(DENIAL_REASON_KEY) REFERENCES DENIAL_REASONS(DENIAL_REASON_KEY),
        CLAIMS_TO_APPEALS AS CLAIMS(APPEAL_STATUS_KEY) REFERENCES APPEAL_STATUSES(APPEAL_STATUS_KEY),
        CLAIMS_TO_PROVIDERS AS CLAIMS(PROVIDER_KEY) REFERENCES PROVIDERS(PROVIDER_KEY)
      )
      FACTS (
        CLAIMS.CLAIM_AMOUNT AS claim_amount COMMENT 'Original billed charge amount in dollars',
        CLAIMS.DENIED_AMOUNT AS denied_amount COMMENT 'Amount denied by payer in dollars',
        CLAIMS.CLAIM_RECORD AS 1 COMMENT 'Count of denial claims',
        CLAIMS.DAYS_TO_RESOLUTION AS days_to_resolution COMMENT 'Days from denial to resolution (appeals only)'
      )
      DIMENSIONS (
        CLAIMS.DATE_OF_SERVICE AS date_of_service WITH SYNONYMS=('DOS','service date') COMMENT 'Date the medical service was provided',
        CLAIMS.DENIAL_DATE AS denial_date WITH SYNONYMS=('denied date','denial date') COMMENT 'Date the claim was denied by the payer',
        CLAIMS.DENIAL_MONTH AS MONTH(denial_date) COMMENT 'Month of the denial',
        CLAIMS.DENIAL_YEAR AS YEAR(denial_date) COMMENT 'Year of the denial',
        CLAIMS.PATIENT_ID AS patient_id COMMENT 'De-identified patient identifier',
        PAYERS.PAYER_NAME AS payer_name WITH SYNONYMS=('insurance','health plan','payer') COMMENT 'Name of the insurance payer',
        PAYERS.PAYER_TYPE AS payer_type WITH SYNONYMS=('insurance type','plan type') COMMENT 'Type of payer: Commercial, Government, Marketplace, Managed Care',
        PROCEDURES.CPT_CODE AS cpt_code WITH SYNONYMS=('procedure code','CPT') COMMENT 'CPT procedure code',
        PROCEDURES.PROCEDURE_DESCRIPTION AS procedure_description WITH SYNONYMS=('procedure','service') COMMENT 'Description of the medical procedure',
        PROCEDURES.PROCEDURE_CATEGORY AS procedure_category WITH SYNONYMS=('service category','procedure type') COMMENT 'Category grouping for procedures',
        PROCEDURES.STANDARD_CHARGE AS standard_charge COMMENT 'Standard charge amount for the procedure',
        DEPARTMENTS.DEPARTMENT_NAME AS department_name WITH SYNONYMS=('department','specialty') COMMENT 'Clinical department name',
        FACILITIES.FACILITY_NAME AS facility_name WITH SYNONYMS=('facility','location','hospital') COMMENT 'Name of the facility',
        FACILITIES.FACILITY_TYPE AS facility_type COMMENT 'Type of facility',
        FACILITIES.CARE_SETTING AS care_setting WITH SYNONYMS=('setting','place of service') COMMENT 'Care setting: Inpatient, Outpatient, Emergency, Ambulatory',
        DENIAL_REASONS.DENIAL_REASON_CODE AS denial_reason_code WITH SYNONYMS=('reason code','CARC','denial code') COMMENT 'CARC denial reason code (e.g., CO-197, CO-16)',
        DENIAL_REASONS.DENIAL_REASON_DESCRIPTION AS denial_reason_description WITH SYNONYMS=('denial reason','reason') COMMENT 'Full description of the denial reason',
        DENIAL_REASONS.DENIAL_CATEGORY AS denial_category COMMENT 'High-level denial category: Coding, Documentation, Authorization, Clinical, Administrative',
        DENIAL_REASONS.DENIAL_SUBCATEGORY AS denial_subcategory COMMENT 'Subcategory within the denial category',
        APPEAL_STATUSES.APPEAL_STATUS AS appeal_status WITH SYNONYMS=('appeal outcome','appeal result') COMMENT 'Current appeal status: Not Appealed, Appeal Filed, Overturned, Upheld, etc.',
        PROVIDERS.PROVIDER_NAME AS provider_name WITH SYNONYMS=('doctor','physician') COMMENT 'Rendering provider name'
      )
      METRICS (
        CLAIMS.TOTAL_DENIALS AS COUNT(CLAIMS.claim_record) COMMENT 'Total number of denied claims',
        CLAIMS.TOTAL_DENIED_AMOUNT AS SUM(CLAIMS.denied_amount) COMMENT 'Total dollar amount denied',
        CLAIMS.TOTAL_CHARGES AS SUM(CLAIMS.claim_amount) COMMENT 'Total original billed charges',
        CLAIMS.AVERAGE_DENIED_AMOUNT AS AVG(CLAIMS.denied_amount) COMMENT 'Average denied amount per claim',
        CLAIMS.DENIAL_RATE AS SUM(CLAIMS.denied_amount) / NULLIF(SUM(CLAIMS.claim_amount), 0) COMMENT 'Denial rate as percentage of total charges',
        CLAIMS.AVG_DAYS_TO_RESOLUTION AS AVG(CLAIMS.days_to_resolution) COMMENT 'Average days from denial to resolution'
      )
      COMMENT='Semantic view for healthcare denial claims analytics — covers denial volumes, reason codes, payer comparisons, appeal outcomes, financial impact, and resolution timelines';


    -- ========================================================================
    -- SEMANTIC VIEW: APPEALS ANALYTICS
    -- ========================================================================

    CREATE OR REPLACE SEMANTIC VIEW HEALTHCARE_AI_DEMO.DENIALS.APPEALS_ANALYTICS_SV
      TABLES (
        APPEALS AS APPEALS_FACT PRIMARY KEY (APPEAL_ID)
          WITH SYNONYMS=('appeal records','appeal data')
          COMMENT='Fact table of all appeals filed against denied claims',
        APPEAL_STATUSES AS APPEAL_STATUS_DIM PRIMARY KEY (APPEAL_STATUS_KEY)
          WITH SYNONYMS=('outcomes','results')
          COMMENT='Appeal outcome dimension',
        CLAIMS AS DENIAL_CLAIMS_FACT PRIMARY KEY (CLAIM_ID)
          COMMENT='Source denial claims linked to appeals',
        PAYERS AS PAYER_DIM PRIMARY KEY (PAYER_KEY)
          COMMENT='Payer dimension for appeal analysis',
        DENIAL_REASONS AS DENIAL_REASON_DIM PRIMARY KEY (DENIAL_REASON_KEY)
          COMMENT='Denial reason for the original claim'
      )
      RELATIONSHIPS (
        APPEALS_TO_STATUSES AS APPEALS(APPEAL_STATUS_KEY) REFERENCES APPEAL_STATUSES(APPEAL_STATUS_KEY),
        APPEALS_TO_CLAIMS AS APPEALS(CLAIM_ID) REFERENCES CLAIMS(CLAIM_ID),
        CLAIMS_TO_PAYERS AS CLAIMS(PAYER_KEY) REFERENCES PAYERS(PAYER_KEY),
        CLAIMS_TO_REASONS AS CLAIMS(DENIAL_REASON_KEY) REFERENCES DENIAL_REASONS(DENIAL_REASON_KEY)
      )
      FACTS (
        APPEALS.DENIED_AMOUNT AS denied_amount COMMENT 'Original denied amount on the appeal',
        APPEALS.RECOVERED_AMOUNT AS recovered_amount COMMENT 'Amount recovered through appeal',
        APPEALS.APPEAL_RECORD AS 1 COMMENT 'Count of appeals'
      )
      DIMENSIONS (
        APPEALS.APPEAL_FILED_DATE AS appeal_filed_date COMMENT 'Date the appeal was filed',
        APPEALS.APPEAL_LEVEL AS appeal_level COMMENT 'Appeal level: 1=First, 2=Second, 3=External Review',
        APPEALS.APPEAL_LEVEL_NAME AS appeal_level_name COMMENT 'Name of the appeal level',
        APPEAL_STATUSES.APPEAL_STATUS AS appeal_status COMMENT 'Appeal outcome',
        PAYERS.PAYER_NAME AS payer_name COMMENT 'Insurance payer name',
        DENIAL_REASONS.DENIAL_REASON_CODE AS denial_reason_code COMMENT 'Original denial reason code',
        DENIAL_REASONS.DENIAL_REASON_DESCRIPTION AS denial_reason_description COMMENT 'Original denial reason'
      )
      METRICS (
        APPEALS.TOTAL_APPEALS AS COUNT(APPEALS.appeal_record) COMMENT 'Total appeals filed',
        APPEALS.TOTAL_RECOVERED AS SUM(APPEALS.recovered_amount) COMMENT 'Total dollars recovered through appeals',
        APPEALS.RECOVERY_RATE AS SUM(APPEALS.recovered_amount) / NULLIF(SUM(APPEALS.denied_amount), 0) COMMENT 'Recovery rate as percentage of denied amount',
        APPEALS.AVERAGE_RECOVERY AS AVG(APPEALS.recovered_amount) COMMENT 'Average recovery per appeal'
      )
      COMMENT='Semantic view for appeal analytics — covers appeal volumes, recovery rates, outcomes by payer and denial reason';


    SHOW SEMANTIC VIEWS;


    -- ========================================================================
    -- UNSTRUCTURED DATA: PARSE DOCUMENTS FOR SEARCH
    -- ========================================================================

    USE ROLE HEALTHCARE_AI_DEMO;

    CREATE OR REPLACE TABLE parsed_content AS
    SELECT
        relative_path,
        BUILD_STAGE_FILE_URL('@HEALTHCARE_AI_DEMO.DENIALS.INTERNAL_DATA_STAGE', relative_path) AS file_url,
        REGEXP_SUBSTR(relative_path, '[^/]+$') AS title,
        REGEXP_SUBSTR(relative_path, 'unstructured_docs/([^/]+)/', 1, 1, 'e') AS doc_category,
        SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
            @HEALTHCARE_AI_DEMO.DENIALS.INTERNAL_DATA_STAGE,
            relative_path,
            {'mode': 'LAYOUT'}
        ):content::STRING AS content
    FROM DIRECTORY(@HEALTHCARE_AI_DEMO.DENIALS.INTERNAL_DATA_STAGE)
    WHERE relative_path ILIKE 'unstructured_docs/%.txt'
       OR relative_path ILIKE 'unstructured_docs/%.pdf';


    -- ========================================================================
    -- CORTEX SEARCH SERVICES
    -- ========================================================================

    CREATE OR REPLACE CORTEX SEARCH SERVICE search_payer_policies
        ON content
        ATTRIBUTES relative_path, file_url, title, doc_category
        WAREHOUSE = HEALTHCARE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT relative_path, file_url, title, doc_category, content
            FROM parsed_content
            WHERE doc_category = 'payer_policies'
        );

    CREATE OR REPLACE CORTEX SEARCH SERVICE search_clinical_guidelines
        ON content
        ATTRIBUTES relative_path, file_url, title, doc_category
        WAREHOUSE = HEALTHCARE_DEMO_WH
        TARGET_LAG = '30 day'
        EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
        AS (
            SELECT relative_path, file_url, title, doc_category, content
            FROM parsed_content
            WHERE doc_category = 'clinical_guidelines'
        );

    SHOW CORTEX SEARCH SERVICES;


    -- ========================================================================
    -- CUSTOM TOOLS: WEB SCRAPER + PRESIGNED URL + EMAIL
    -- ========================================================================

    USE ROLE HEALTHCARE_AI_DEMO;

    CREATE OR REPLACE NETWORK RULE healthcare_web_access_rule
      MODE = EGRESS
      TYPE = HOST_PORT
      VALUE_LIST = ('0.0.0.0:80', '0.0.0.0:443');

    USE ROLE ACCOUNTADMIN;

    GRANT ALL PRIVILEGES ON DATABASE HEALTHCARE_AI_DEMO TO ROLE ACCOUNTADMIN;
    GRANT ALL PRIVILEGES ON SCHEMA HEALTHCARE_AI_DEMO.DENIALS TO ROLE ACCOUNTADMIN;
    GRANT USAGE ON NETWORK RULE HEALTHCARE_AI_DEMO.DENIALS.healthcare_web_access_rule TO ROLE ACCOUNTADMIN;

    USE SCHEMA HEALTHCARE_AI_DEMO.DENIALS;

    CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION healthcare_external_access
    ALLOWED_NETWORK_RULES = (HEALTHCARE_AI_DEMO.DENIALS.healthcare_web_access_rule)
    ENABLED = TRUE;

    CREATE OR REPLACE NOTIFICATION INTEGRATION healthcare_email_int
      TYPE = EMAIL
      ENABLED = TRUE;

    GRANT CREATE AGENT ON SCHEMA HEALTHCARE_AI_DEMO.DENIALS TO ROLE HEALTHCARE_AI_DEMO;
    GRANT USAGE ON INTEGRATION healthcare_external_access TO ROLE HEALTHCARE_AI_DEMO;
    GRANT USAGE ON INTEGRATION healthcare_email_int TO ROLE HEALTHCARE_AI_DEMO;

    USE ROLE HEALTHCARE_AI_DEMO;

    CREATE OR REPLACE PROCEDURE Get_File_Presigned_URL_SP(
        RELATIVE_FILE_PATH STRING,
        EXPIRATION_MINS INTEGER DEFAULT 60
    )
    RETURNS STRING
    LANGUAGE SQL
    COMMENT = 'Generates a presigned URL for a document in the internal stage'
    EXECUTE AS CALLER
    AS
    $$
    DECLARE
        presigned_url STRING;
        sql_stmt STRING;
        expiration_seconds INTEGER;
        stage_name STRING DEFAULT '@HEALTHCARE_AI_DEMO.DENIALS.INTERNAL_DATA_STAGE';
    BEGIN
        expiration_seconds := EXPIRATION_MINS * 60;
        sql_stmt := 'SELECT GET_PRESIGNED_URL(' || stage_name || ', ' || '''' || RELATIVE_FILE_PATH || '''' || ', ' || expiration_seconds || ') AS url';
        EXECUTE IMMEDIATE :sql_stmt;
        SELECT "URL" INTO :presigned_url FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
        RETURN :presigned_url;
    END;
    $$;

    CREATE OR REPLACE PROCEDURE send_mail(recipient TEXT, subject TEXT, text TEXT)
    RETURNS TEXT
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python')
    HANDLER = 'send_mail'
    AS
    $$
def send_mail(session, recipient, subject, text):
    session.call('SYSTEM$SEND_EMAIL', 'healthcare_email_int', recipient, subject, text, 'text/html')
    return f'Email sent to {recipient} with subject: "{subject}".'
    $$;

    CREATE OR REPLACE FUNCTION web_scrape(weburl STRING)
    RETURNS STRING
    LANGUAGE PYTHON
    RUNTIME_VERSION = 3.11
    HANDLER = 'get_page'
    EXTERNAL_ACCESS_INTEGRATIONS = (healthcare_external_access)
    PACKAGES = ('requests', 'beautifulsoup4')
    AS
    $$
import requests
from bs4 import BeautifulSoup

def get_page(weburl):
    response = requests.get(weburl)
    soup = BeautifulSoup(response.text)
    return soup.get_text()
    $$;


    -- ========================================================================
    -- SNOWFLAKE INTELLIGENCE AGENT
    -- ========================================================================

    USE ROLE HEALTHCARE_AI_DEMO;

    CREATE OR REPLACE AGENT HEALTHCARE_AI_DEMO.DENIALS.Healthcare_Denial_Management_Agent
    WITH PROFILE='{ "display_name": "Healthcare Denial Management Agent", "color": "blue" }'
        COMMENT=$$ AI agent for healthcare denial management — queries denial data, searches payer policies and clinical guidelines, and provides actionable insights for revenue cycle teams. $$
    FROM SPECIFICATION $$
    {
      "models": {
        "orchestration": ""
      },
      "instructions": {
        "response": "You are a healthcare denial management assistant for Grady Health System. Provide clear, actionable insights about claim denials, appeal strategies, and payer policies. Always cite your sources — reference specific policy documents or data queries. Format financial data as currency with commas. Format dates as MM/DD/YYYY. When showing trends, default to line charts. When comparing categories, default to bar charts. Always include an Action Items section with specific next steps the revenue cycle team should take.",
        "orchestration": "For questions about denial counts, trends, rates, financial amounts, appeal outcomes, payer comparisons, department breakdowns, or any quantitative analysis, use the Denial Analytics or Appeals Analytics tools. For questions about payer policies, coverage criteria, documentation requirements, prior authorization rules, or appeal procedures, use the Payer Policy Search tool. For questions about internal clinical guidelines, coding standards, or workflow procedures, use the Clinical Guidelines Search tool. If a question spans both structured data and documents, use multiple tools. For web content analysis, use the web scraper tool.",
        "sample_questions": [
          { "question": "What are our top denial reasons this quarter by total denied amount?" },
          { "question": "What does the Aetna policy say about cardiac catheterization prior auth?" },
          { "question": "Which payer has the highest denial rate and what are their common reasons?" },
          { "question": "Show me the trend of CO-197 prior auth denials over the past 12 months" },
          { "question": "What is our appeal overturn rate by payer?" },
          { "question": "How can we reduce CO-16 missing information denials from UnitedHealthcare?" }
        ]
      },
      "tools": [
        {
          "tool_spec": {
            "type": "cortex_analyst_text_to_sql",
            "name": "Denial_Analytics",
            "description": "Queries structured denial claims data for Grady Health System. Use for questions about denial counts, rates, trends, financial amounts, payer comparisons, department breakdowns, facility analysis, procedure-level denials, and any quantitative analysis of claim denials."
          }
        },
        {
          "tool_spec": {
            "type": "cortex_analyst_text_to_sql",
            "name": "Appeals_Analytics",
            "description": "Queries appeal data including appeal outcomes, recovery amounts, overturn rates, and appeal timelines. Use for questions about appeal success rates, recovered dollars, appeal levels, and appeal performance by payer or denial reason."
          }
        },
        {
          "tool_spec": {
            "type": "cortex_search",
            "name": "Payer_Policy_Search",
            "description": "Searches payer policy documents including coverage criteria, prior authorization requirements, claims submission guidelines, and appeal procedures. Use for questions about specific payer rules, denial code explanations, required documentation, filing deadlines, and how to prevent specific types of denials."
          }
        },
        {
          "tool_spec": {
            "type": "cortex_search",
            "name": "Clinical_Guidelines_Search",
            "description": "Searches internal clinical guidelines and operational procedures for Grady Health System. Use for questions about internal coding standards, documentation requirements, denial management workflows, imaging authorization processes, and ED visit level documentation."
          }
        },
        {
          "tool_spec": {
            "type": "data_to_chart",
            "name": "data_to_chart",
            "description": "Generates visualizations from denial and appeal data queries"
          }
        },
        {
          "tool_spec": {
            "type": "generic",
            "name": "Web_Scraper",
            "description": "Scrapes and analyzes content from a web URL. Use when the user wants to analyze external content such as payer websites, CMS updates, or regulatory guidance.",
            "input_schema": {
              "type": "object",
              "properties": {
                "weburl": {
                  "description": "Full web URL including http:// or https://",
                  "type": "string"
                }
              },
              "required": ["weburl"]
            }
          }
        },
        {
          "tool_spec": {
            "type": "generic",
            "name": "Send_Email",
            "description": "Sends an email to a recipient. Use when the user wants to email a summary, report, or alert to a colleague.",
            "input_schema": {
              "type": "object",
              "properties": {
                "recipient": { "description": "Email address of the recipient", "type": "string" },
                "subject": { "description": "Email subject line", "type": "string" },
                "text": { "description": "Email body content in HTML format", "type": "string" }
              },
              "required": ["recipient", "subject", "text"]
            }
          }
        },
        {
          "tool_spec": {
            "type": "generic",
            "name": "Document_Download_URL",
            "description": "Generates a temporary download URL for policy documents and clinical guidelines stored in the internal stage. Use when a user wants to download or share a specific document.",
            "input_schema": {
              "type": "object",
              "properties": {
                "relative_file_path": { "description": "Relative path of the file from Cortex Search results", "type": "string" },
                "expiration_mins": { "description": "URL expiration in minutes, default 5", "type": "number" }
              },
              "required": ["relative_file_path", "expiration_mins"]
            }
          }
        }
      ],
      "tool_resources": {
        "Denial_Analytics": {
          "semantic_view": "HEALTHCARE_AI_DEMO.DENIALS.DENIAL_ANALYTICS_SV"
        },
        "Appeals_Analytics": {
          "semantic_view": "HEALTHCARE_AI_DEMO.DENIALS.APPEALS_ANALYTICS_SV"
        },
        "Payer_Policy_Search": {
          "name": "HEALTHCARE_AI_DEMO.DENIALS.SEARCH_PAYER_POLICIES",
          "max_results": 5,
          "title_column": "TITLE",
          "id_column": "RELATIVE_PATH"
        },
        "Clinical_Guidelines_Search": {
          "name": "HEALTHCARE_AI_DEMO.DENIALS.SEARCH_CLINICAL_GUIDELINES",
          "max_results": 5,
          "title_column": "TITLE",
          "id_column": "RELATIVE_PATH"
        },
        "Web_Scraper": {
          "execution_environment": { "type": "warehouse", "warehouse": "HEALTHCARE_DEMO_WH", "query_timeout": 0 },
          "identifier": "HEALTHCARE_AI_DEMO.DENIALS.WEB_SCRAPE",
          "name": "WEB_SCRAPE(VARCHAR)",
          "type": "function"
        },
        "Send_Email": {
          "execution_environment": { "type": "warehouse", "warehouse": "HEALTHCARE_DEMO_WH", "query_timeout": 0 },
          "identifier": "HEALTHCARE_AI_DEMO.DENIALS.SEND_MAIL",
          "name": "SEND_MAIL(VARCHAR, VARCHAR, VARCHAR)",
          "type": "procedure"
        },
        "Document_Download_URL": {
          "execution_environment": { "type": "warehouse", "warehouse": "HEALTHCARE_DEMO_WH", "query_timeout": 0 },
          "identifier": "HEALTHCARE_AI_DEMO.DENIALS.GET_FILE_PRESIGNED_URL_SP",
          "name": "GET_FILE_PRESIGNED_URL_SP(VARCHAR, DEFAULT NUMBER)",
          "type": "procedure"
        }
      }
    }
    $$;


    -- ========================================================================
    -- FINAL VERIFICATION
    -- ========================================================================

    SHOW TABLES IN SCHEMA HEALTHCARE_AI_DEMO.DENIALS;
    SHOW SEMANTIC VIEWS IN SCHEMA HEALTHCARE_AI_DEMO.DENIALS;
    SHOW CORTEX SEARCH SERVICES IN SCHEMA HEALTHCARE_AI_DEMO.DENIALS;
    SHOW AGENTS IN SCHEMA HEALTHCARE_AI_DEMO.DENIALS;

    SELECT '✅ Healthcare AI Demo setup complete!' AS status;
