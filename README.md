# Healthcare AI Demo — Snowflake Intelligence for Denial Management

**Copy, Paste, Run & Done in less than 10 mins!**

Just run the SQL script as an ACCOUNTADMIN as-is and you're done!

This project demonstrates Snowflake Intelligence capabilities applied to **healthcare denial management**, including:

- **Cortex Analyst** (Text-to-SQL via semantic views over denial claims and appeals data)
- **Cortex Search** (Hybrid search over payer policies and clinical guidelines)
- **Snowflake Intelligence Agent** (Multi-tool AI agent with orchestration)
- **Git Integration** (Automated data loading from GitHub repository)

---

## Key Components

### 1. Data Infrastructure

- **Star Schema Design:** 8 dimension tables and 3 fact tables covering Revenue Cycle, Clinical Operations, and Compliance
- **Realistic Sample Data:** 8,000+ denied claims, 5,100+ appeals, 238 monthly summaries across 10 payers, 15 departments, 8 facilities, 50 providers, and 25 procedures
- **Date Range:** January 2024 through December 2025
- **Database:** `HEALTHCARE_AI_DEMO` with schema `DENIALS`
- **Warehouse:** `HEALTHCARE_DEMO_WH` (XSMALL with auto-suspend/resume)

### 2. Semantic Views (2 Business Domains)

- **Denial Analytics:** Denial claims joined to payers, procedures, departments, facilities, providers, denial reasons, and appeal statuses. Includes metrics for total denials, denied amounts, denial rate, and average days to resolution.
- **Appeals Analytics:** Appeals data joined to original denial claims, payers, and denial reasons. Includes metrics for total appeals, recovered dollars, and recovery rate.

### 3. Cortex Search Services (2 Domain-Specific)

- **Payer Policies:** Aetna cardiac catheterization policy, BCBS surgical prior auth guidelines, UnitedHealthcare claims documentation requirements, Cigna non-covered services policy, CMS Medicare timely filing requirements, Georgia Medicaid claims guidelines
- **Clinical Guidelines:** Imaging prior authorization requirements, ED visit level documentation guidelines, denial management and appeals workflow

### 4. Snowflake Intelligence Agent

- **Multi-Tool Agent:** Combines Cortex Analyst (2 semantic views), Cortex Search (2 search services), web scraping, email, document download, and chart generation
- **Healthcare-Specific Orchestration:** Routes denial data questions to Analyst, policy questions to Search, and complex questions to both
- **Custom Tools:** Web scraper for external content, email for alerts/reports, presigned URL for document sharing

---

## Database Schema

### Dimension Tables (8)

| Table | Description | Rows |
|-------|-------------|------|
| `payer_dim` | Insurance payers (Aetna, BCBS, UHC, Cigna, etc.) | 10 |
| `facility_dim` | Hospital facilities and care settings | 8 |
| `department_dim` | Clinical departments (Cardiology, Orthopedics, etc.) | 15 |
| `provider_dim` | Rendering physicians with NPI | 50 |
| `procedure_dim` | CPT codes with descriptions and charges | 25 |
| `denial_reason_dim` | CARC denial codes (CO-4, CO-16, CO-197, etc.) | 15 |
| `appeal_status_dim` | Appeal outcomes (Overturned, Upheld, Pending, etc.) | 7 |
| `date_dim` | Calendar dates 2024-2025 | 731 |

### Fact Tables (3)

| Table | Description | Rows |
|-------|-------------|------|
| `denial_claims_fact` | Individual denied claims with financials and resolution | ~8,000 |
| `appeals_fact` | Appeals filed with recovery amounts | ~5,100 |
| `monthly_denial_summary` | Aggregated monthly denial metrics by payer | ~238 |

---

## Setup Instructions

**Single Script Setup:** The entire demo environment is created with one script.

1. Run the complete setup script in a Snowflake worksheet:

   ```sql
   -- Execute as ACCOUNTADMIN
   @HEALTHCARE_AI_DEMO_REPO/branches/main/sql_scripts/demo_setup.sql
   ```

2. **Before running**, update the Git repository URL in the script:
   - Find `YOUR_ORG` and replace with your GitHub organization/username
   - Update the `API_ALLOWED_PREFIXES` and `ORIGIN` URLs

3. What the script creates:
   - `HEALTHCARE_AI_DEMO` role and permissions
   - `HEALTHCARE_DEMO_WH` warehouse
   - `HEALTHCARE_AI_DEMO.DENIALS` database and schema
   - Git repository integration
   - 8 dimension tables + 3 fact tables with data
   - 2 semantic views for Cortex Analyst
   - 2 Cortex Search services for documents
   - Web scraping function with external access integration
   - Presigned URL function for document sharing
   - Email function for sending reports
   - 1 Snowflake Intelligence Agent with all tools

4. Post-Setup Verification:

   ```sql
   SHOW TABLES;                    -- Verify 11 tables + parsed_content
   SHOW SEMANTIC VIEWS;            -- Verify 2 semantic views
   SHOW CORTEX SEARCH SERVICES;    -- Verify 2 search services
   SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;  -- Verify 1 agent
   ```

---

## Agent Capabilities

The Healthcare Denial Management Agent can:

- Analyze denial volumes, trends, and financial impact across payers, departments, facilities, and procedures
- Compare appeal overturn rates and recovery amounts by payer and denial reason
- Search payer policy documents for coverage criteria, prior auth requirements, and documentation rules
- Search internal clinical guidelines for coding standards, workflow procedures, and compliance requirements
- Generate visualizations including trend lines, bar charts, and comparative analytics
- Scrape external web content for CMS updates, payer bulletins, or regulatory guidance
- Email summaries, alerts, and reports to stakeholders
- Generate secure download links for internal documents
- Combine insights from structured data and policy documents for comprehensive, actionable answers

---

## Demo Script: Healthcare Denial Management

The following questions demonstrate the agent's ability to perform cross-domain analysis connecting denial data with payer policies and clinical guidelines.

### Denial Performance Analysis

1. **Monthly Trends**
   "Show me monthly denial trends for 2025 with a line chart. Which months had the highest denied amounts?"

2. **Top Denial Reasons**
   "What are our top 5 denial reasons by total denied amount? Show me a bar chart."

3. **Payer Comparison**
   "Compare denial rates across all payers. Which payer has the highest denial rate and what are their most common reasons?"

### Root Cause Investigation

4. **Prior Auth Denials**
   "We're seeing a lot of CO-197 prior auth denials. Which departments and procedures are most affected? What do the payer policies say about prior auth requirements?"

5. **Missing Documentation**
   "How many CO-16 denials do we have from UnitedHealthcare, and what's the total dollar impact? What specific documentation does UHC require that we might be missing?"

6. **Modifier Issues**
   "Show me CO-4 modifier denials by procedure. What does the Aetna policy say about correct modifier usage for cardiac catheterization?"

### Appeal Strategy

7. **Appeal Performance**
   "What is our appeal overturn rate by payer? Which payers are easiest to overturn?"

8. **Recovery Analysis**
   "How much money have we recovered through appeals in 2025? Show me the trend by month."

9. **Appeal Prioritization**
   "Which denial reasons have the highest appeal success rate? Where should we focus our appeal efforts for maximum ROI?"

### Cross-Domain Insights

10. **Policy-Guided Action**
    "We had a $45,000 total knee replacement denied by Blue Cross for prior auth. What are BCBS's specific requirements for orthopedic procedures, and how should we appeal?"

11. **Department Deep Dive**
    "How is the Cardiology department performing on denials? What are their top denial reasons, and what do our internal guidelines say about imaging prior auth?"

12. **Executive Summary**
    "Give me an executive summary of our denial performance — total denied dollars, denial rate trend, top 3 action items, and the biggest revenue recovery opportunities."

### Demo Flow Recommendation

1. **Start with trends** — establish the denial landscape with monthly trends and KPIs
2. **Drill into reasons** — identify the top denial categories driving volume and dollars
3. **Investigate root causes** — use Search to find payer-specific requirements
4. **Analyze appeals** — show recovery rates and prioritize by ROI
5. **Cross-domain synthesis** — demonstrate a complex question that uses both Analyst and Search
6. **Actionable output** — email a summary or generate a document download link

---

## Repository Structure

```
Healthcare_AI_DEMO/
├── README.md
├── demo_data/
│   ├── payer_dim.csv
│   ├── facility_dim.csv
│   ├── department_dim.csv
│   ├── provider_dim.csv
│   ├── procedure_dim.csv
│   ├── denial_reason_dim.csv
│   ├── appeal_status_dim.csv
│   ├── date_dim.csv
│   ├── denial_claims_fact.csv
│   ├── appeals_fact.csv
│   └── monthly_denial_summary.csv
├── unstructured_docs/
│   ├── payer_policies/
│   │   ├── Aetna_Cardiac_Catheterization_Policy.txt
│   │   ├── BCBS_Surgical_Prior_Auth_Guidelines.txt
│   │   ├── UnitedHealthcare_Claims_Documentation_Requirements.txt
│   │   ├── Cigna_Non_Covered_Services_Policy.txt
│   │   ├── CMS_Medicare_Timely_Filing_Requirements.txt
│   │   └── Georgia_Medicaid_Claims_Guidelines.txt
│   └── clinical_guidelines/
│       ├── Imaging_Prior_Authorization_Requirements.txt
│       ├── ED_Visit_Level_Documentation_Guidelines.txt
│       └── Denial_Management_Appeals_Workflow.txt
├── sql_scripts/
│   └── demo_setup.sql
└── images/
```

---

## Data Flow

1. **Source Repository:** GitHub repo contains CSV data files and unstructured policy/guideline documents
2. **Git Integration:** Snowflake Git API pulls all files to an internal stage
3. **Structured Data:** CSVs populate 8 dimension tables and 3 fact tables in a star schema
4. **Unstructured Data:** Text documents are parsed via `CORTEX.PARSE_DOCUMENT` into the `parsed_content` table
5. **Semantic Layer:** 2 semantic views provide natural language query capability over denial and appeal data
6. **Search Services:** 2 Cortex Search services enable hybrid search over payer policies and clinical guidelines
7. **Custom Tools:** Web scraper, email, and document URL functions extend the agent's capabilities
8. **AI Orchestration:** The Snowflake Intelligence Agent orchestrates across all tools
9. **User Access:** Users interact through Snowflake Intelligence using natural language

---

## Prerequisites

- Snowflake account with ACCOUNTADMIN access
- Cross-region inference recommended:
  ```sql
  ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
  ```
- `SNOWFLAKE.CORTEX_USER` database role granted to the demo role
