--Create and Use database
CREATE DATABASE Fintech_Complaint_Analytics;
USE Fintech_Complaint_Analytics;

-- Create Table
CREATE TABLE dbo.CFPB_Complaints_Staging
(
    [Date received] NVARCHAR(50),
    [Product] NVARCHAR(500),
    [Sub-product] NVARCHAR(500),
    [Issue] NVARCHAR(1000),
    [Sub-issue] NVARCHAR(1000),
    [Consumer complaint narrative] NVARCHAR(MAX),
    [Company public response] NVARCHAR(1000),
    [Company] NVARCHAR(500),
    [State] NVARCHAR(50),
    [ZIP code] NVARCHAR(50),
    [Tags] NVARCHAR(500),
    [Submitted via] NVARCHAR(100),
    [Date sent to company] NVARCHAR(100),
    [Company response to consumer] NVARCHAR(1000),
    [Timely response?] NVARCHAR(50),
    [Complaint ID] NVARCHAR(50)
);

--Insert the values into table
BULK INSERT dbo.CFPB_Complaints_Staging
FROM 'C:\Users\Chandu S N\Downloads\complaints\complaints.csv'
WITH
(
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK,
    MAXERRORS = 100
);

--Row count
SELECT COUNT(*) AS total_rows
FROM dbo.CFPB_Complaints_Staging;

--check the actual data
SELECT TOP 10 *
FROM dbo.CFPB_Complaints_Staging;

--Check dulpicate complaint IDs
SELECT
    [Complaint ID],
    COUNT(*) AS occurrences
FROM dbo.CFPB_Complaints_Staging
GROUP BY [Complaint ID]
HAVING COUNT(*) > 1;

--Check date range
SELECT
    MIN(TRY_CONVERT(date, [Date received])) AS earliest_date,
    MAX(TRY_CONVERT(date, [Date received])) AS latest_date
FROM dbo.CFPB_Complaints_Staging;


--Check missing values
SELECT
    SUM(CASE WHEN [Date received] IS NULL OR TRIM([Date received]) = '' THEN 1 ELSE 0 END) AS missing_date,
    SUM(CASE WHEN Product IS NULL OR TRIM(Product) = '' THEN 1 ELSE 0 END) AS missing_product,
    SUM(CASE WHEN Issue IS NULL OR TRIM(Issue) = '' THEN 1 ELSE 0 END) AS missing_issue,
    SUM(CASE WHEN Company IS NULL OR TRIM(Company) = '' THEN 1 ELSE 0 END) AS missing_company,
    SUM(CASE WHEN [Submitted via] IS NULL OR TRIM([Submitted via]) = '' THEN 1 ELSE 0 END) AS missing_channel,
    SUM(CASE WHEN [Timely response?] IS NULL OR TRIM([Timely response?]) = '' THEN 1 ELSE 0 END) AS missing_timely_response
FROM dbo.CFPB_Complaints_Staging;

--Identify missing product records
SELECT
    COUNT(*) AS missing_product_count
FROM dbo.CFPB_Complaints_Staging
WHERE Product IS NULL
   OR TRIM(Product) = '';

SELECT TOP 20
    [Complaint ID],
    [Date received],
    Product,
    [Sub-product],
    Issue,
    [Company]
FROM dbo.CFPB_Complaints_Staging
WHERE Product IS NULL
   OR TRIM(Product) = '';

--Identify missing issue records
SELECT
    COUNT(*) AS missing_issue_count
FROM dbo.CFPB_Complaints_Staging
WHERE Issue IS NULL
   OR TRIM(Issue) = '';

SELECT TOP 20
    [Complaint ID],
    [Date received],
    Product,
    [Sub-product],
    Issue,
    [Sub-issue],
    [Company]
FROM dbo.CFPB_Complaints_Staging
WHERE Issue IS NULL
   OR TRIM(Issue) = '';

--Check the date received values
SELECT
    [Date received],
    COUNT(*) AS records
FROM dbo.CFPB_Complaints_Staging
GROUP BY [Date received]
ORDER BY [Date received];

--Check timely response values
SELECT
    [Timely response?],
    COUNT(*) AS records
FROM dbo.CFPB_Complaints_Staging
GROUP BY [Timely response?]
ORDER BY records DESC;

--Check Response categories
SELECT
    [Company response to consumer],
    COUNT(*) AS records
FROM dbo.CFPB_Complaints_Staging
GROUP BY [Company response to consumer]
ORDER BY records DESC;

--Q1. What does our complaint portfolio look like?
SELECT
    COUNT(*) AS total_complaints,
    COUNT(DISTINCT [Complaint ID]) AS unique_complaints,
    COUNT(DISTINCT Company) AS companies,
    COUNT(DISTINCT Product) AS products,
    COUNT(DISTINCT State) AS states
FROM dbo.CFPB_Complaints_Staging;

--Q2. Which financial products generate the most complaints, and how has complaint volume changed over time?
SELECT
    YEAR([Date received]) AS complaint_year,
    Product,
    COUNT(*) AS complaint_count
FROM dbo.CFPB_Complaints_Staging
GROUP BY
    YEAR([Date received]),
    Product
ORDER BY
    complaint_year,
    complaint_count DESC;

SELECT
    DATEFROMPARTS(
        YEAR([Date received]),
        MONTH([Date received]),
        1
    ) AS complaint_month,
    Product,
    COUNT(*) AS complaint_count
FROM dbo.CFPB_Complaints_Staging
GROUP BY
    DATEFROMPARTS(
        YEAR([Date received]),
        MONTH([Date received]),
        1
    ),
    Product
ORDER BY complaint_month;

--Q3. Which specific issues are responsible for the largest share of complaints within each product?
WITH issue_counts AS
(
    SELECT
        Product,
        Issue,
        COUNT(*) AS complaint_count
    FROM dbo.CFPB_Complaints_Staging
    GROUP BY Product, Issue
),
ranked AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY Product
            ORDER BY complaint_count DESC
        ) AS issue_rank
    FROM issue_counts
)
SELECT
    Product,
    Issue,
    complaint_count,
    issue_rank
FROM ranked
WHERE issue_rank <= 5
ORDER BY Product, issue_rank;

--Q4. Which companies have unusually high complaint volumes relative to their overall complaint portfolio?
WITH company_product AS
(
    SELECT
        Company,
        Product,
        COUNT(*) AS complaints
    FROM dbo.CFPB_Complaints_Staging
    GROUP BY Company, Product
),
company_total AS
(
    SELECT
        Company,
        SUM(complaints) AS total_complaints
    FROM company_product
    GROUP BY Company
)
SELECT
    cp.Company,
    cp.Product,
    cp.complaints,
    ct.total_complaints,
    CAST(
        100.0 * cp.complaints / ct.total_complaints
        AS DECIMAL(10,2)
    ) AS product_share_pct
FROM company_product cp
JOIN company_total ct
    ON cp.Company = ct.Company
ORDER BY
    cp.Company,
    product_share_pct DESC;

--Q5. Which companies have the weakest timely-response performance?
SELECT
    Company,
    COUNT(*) AS complaints_sent_to_company,
    SUM(
        CASE
            WHEN [Timely response?] = 'Yes' THEN 1
            ELSE 0
        END
    ) AS timely_responses,
    CAST(
        100.0 *
        SUM(CASE WHEN [Timely response?] = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(
            SUM(
                CASE
                    WHEN [Timely response?] IS NOT NULL
                    THEN 1 ELSE 0
                END
            ), 0
        )
        AS DECIMAL(10,2)
    ) AS timely_response_rate
FROM dbo.CFPB_Complaints_Staging
GROUP BY Company
HAVING COUNT(*) >= 100
ORDER BY timely_response_rate;

--Q6. Which complaint issues are most associated with untimely responses?
SELECT
    Issue,
    COUNT(*) AS complaints,
    SUM(
        CASE
            WHEN [Timely response?] = 'No' THEN 1
            ELSE 0
        END
    ) AS untimely,
    CAST(
        100.0 *
        SUM(CASE WHEN [Timely response?] = 'No' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0)
        AS DECIMAL(10,2)
    ) AS untimely_rate
FROM dbo.CFPB_Complaints_Staging
WHERE [Timely response?] IS NOT NULL
GROUP BY Issue
HAVING COUNT(*) >= 100
ORDER BY untimely_rate DESC;

--Q7. Are certain complaint submission channels associated with different response performance?
SELECT
    [Submitted via],
    COUNT(*) AS complaints,
    SUM(
        CASE
            WHEN [Timely response?] = 'Yes' THEN 1
            ELSE 0
        END
    ) AS timely,
    CAST(
        100.0 *
        SUM(CASE WHEN [Timely response?] = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0)
        AS DECIMAL(10,2)
    ) AS timely_response_rate
FROM dbo.CFPB_Complaints_Staging
GROUP BY [Submitted via]
ORDER BY timely_response_rate DESC;

--Q8. Which product–issue combinations are becoming increasingly important over time?
WITH monthly AS
(
    SELECT
        Product,
        Issue,
        DATEFROMPARTS(
            YEAR([Date received]),
            MONTH([Date received]),
            1
        ) AS complaint_month,
        COUNT(*) AS complaints
    FROM dbo.CFPB_Complaints_Staging
    GROUP BY
        Product,
        Issue,
        DATEFROMPARTS(
            YEAR([Date received]),
            MONTH([Date received]),
            1
        )
),
growth AS
(
    SELECT
        *,
        LAG(complaints) OVER
        (
            PARTITION BY Product, Issue
            ORDER BY complaint_month
        ) AS previous_month
    FROM monthly
)
SELECT
    Product,
    Issue,
    complaint_month,
    complaints,
    previous_month,
    complaints - previous_month AS change_from_previous_month,
    CAST(
        100.0 * (complaints - previous_month)
        / NULLIF(previous_month,0)
        AS DECIMAL(10,2)
    ) AS pct_change
FROM growth
WHERE previous_month IS NOT NULL
ORDER BY pct_change DESC;

/*Q9. Which product–issue combinations should management prioritize based on both complaint volume and response performance?

First calculate the two dimensions:

complaint volume
untimely response rate */

SELECT
    Product,
    Issue,
    COUNT(*) AS complaints,

    SUM(
        CASE
            WHEN [Timely response?] = 'No'
            THEN 1 ELSE 0
        END
    ) AS untimely_responses,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN [Timely response?] = 'No'
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*),0)
        AS DECIMAL(10,2)
    ) AS untimely_rate

FROM dbo.CFPB_Complaints_Staging
WHERE [Timely response?] IS NOT NULL
GROUP BY Product, Issue
HAVING COUNT(*) >= 100
ORDER BY complaints DESC, untimely_rate DESC;


WITH metrics AS
(
    SELECT
        Product,
        Issue,
        COUNT(*) AS complaints,
        CAST(
            100.0 *
            SUM(
                CASE
                    WHEN [Timely response?] = 'No'
                    THEN 1 ELSE 0
                END
            ) / NULLIF(COUNT(*),0)
            AS DECIMAL(10,2)
        ) AS untimely_rate
    FROM dbo.CFPB_Complaints_Staging
    WHERE [Timely response?] IS NOT NULL
    GROUP BY Product, Issue
    HAVING COUNT(*) >= 100
),
benchmarks AS
(
    SELECT
        *,
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY complaints)
        OVER () AS volume_75th,
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY untimely_rate)
        OVER () AS untimely_75th
    FROM metrics
)
SELECT
    Product,
    Issue,
    complaints,
    untimely_rate,
    CASE
        WHEN complaints >= volume_75th
         AND untimely_rate >= untimely_75th
            THEN 'HIGH PRIORITY'
        WHEN complaints >= volume_75th
            THEN 'HIGH VOLUME'
        WHEN untimely_rate >= untimely_75th
            THEN 'RESPONSE RISK'
        ELSE 'LOWER PRIORITY'
    END AS priority
FROM benchmarks
ORDER BY complaints DESC;

/*Q10. Which companies have the greatest complaint-response risk after accounting for the types of products they handle?

This is the hardest SQL question.

Don't simply rank companies by raw complaint count.

First calculate each company's product mix.*/

WITH company_product AS
(
    SELECT
        Company,
        Product,
        COUNT(*) AS complaints,
        SUM(
            CASE
                WHEN [Timely response?] = 'No'
                THEN 1 ELSE 0
            END
        ) AS untimely
    FROM dbo.CFPB_Complaints_Staging
    WHERE [Timely response?] IS NOT NULL
    GROUP BY Company, Product
),
product_benchmark AS
(
    SELECT
        Product,
        CAST(
            100.0 * SUM(untimely)
            / NULLIF(SUM(complaints),0)
            AS DECIMAL(10,2)
        ) AS product_untimely_rate
    FROM company_product
    GROUP BY Product
)
SELECT
    cp.Company,
    SUM(cp.complaints) AS total_complaints,
    SUM(cp.untimely) AS total_untimely,
    CAST(
        100.0 * SUM(cp.untimely)
        / NULLIF(SUM(cp.complaints),0)
        AS DECIMAL(10,2)
    ) AS actual_untimely_rate,

    CAST(
        SUM(
            cp.complaints *
            pb.product_untimely_rate / 100.0
        )
        / NULLIF(SUM(cp.complaints),0)
        AS DECIMAL(10,2)
    ) AS expected_untimely_rate

FROM company_product cp
JOIN product_benchmark pb
    ON cp.Product = pb.Product

GROUP BY cp.Company
HAVING SUM(cp.complaints) >= 500
ORDER BY actual_untimely_rate DESC;