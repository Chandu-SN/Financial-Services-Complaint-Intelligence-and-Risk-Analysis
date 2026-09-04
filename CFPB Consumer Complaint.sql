/*====================================================================
    1. CREATE / USE DATABASE
====================================================================*/

CREATE DATABASE Fintech_Complaint_Analytics;

USE Fintech_Complaint_Analytics;

/*====================================================================
    2. CREATE RAW / STAGING TABLE
====================================================================*/
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



/*====================================================================
    3. BASIC DATA VALIDATION
====================================================================*/

-- Total records and unique complaint IDs

SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT [Complaint ID]) AS Unique_Complaints,
    COUNT(*) - COUNT(DISTINCT [Complaint ID]) AS Missing_Complaint_ID_Rows
FROM dbo.CFPB_Complaints_Staging;


-- Check for duplicate NON-NULL complaint IDs

SELECT
    [Complaint ID],
    COUNT(*) AS Occurrences
FROM dbo.CFPB_Complaints_Staging
WHERE [Complaint ID] IS NOT NULL
  AND TRIM([Complaint ID]) <> ''
GROUP BY [Complaint ID]
HAVING COUNT(*) > 1
ORDER BY Occurrences DESC;


-- Date range

SELECT
    MIN(
        TRY_CONVERT(
            datetime2(0),
            REPLACE(TRIM([Date received]), 'Z', ''),
            126
        )
    ) AS Earliest_Date,

    MAX(
        TRY_CONVERT(
            datetime2(0),
            REPLACE(TRIM([Date received]), 'Z', ''),
            126
        )
    ) AS Latest_Date
FROM dbo.CFPB_Complaints_Staging;


/*====================================================================
    4. DATA QUALITY CHECK
====================================================================*/

SELECT
    COUNT(*) AS Total_Rows,

    SUM(
        CASE
            WHEN [Complaint ID] IS NULL
              OR TRIM([Complaint ID]) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Complaint_ID,

    SUM(
        CASE
            WHEN [Date received] IS NULL
              OR TRIM([Date received]) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Date_Received,

    SUM(
        CASE
            WHEN Product IS NULL
              OR TRIM(Product) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Product,

    SUM(
        CASE
            WHEN [Sub-product] IS NULL
              OR TRIM([Sub-product]) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Sub_Product,

    SUM(
        CASE
            WHEN Issue IS NULL
              OR TRIM(Issue) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Issue,

    SUM(
        CASE
            WHEN [Sub-issue] IS NULL
              OR TRIM([Sub-issue]) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Sub_Issue,

    SUM(
        CASE
            WHEN Company IS NULL
              OR TRIM(Company) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Company,

    SUM(
        CASE
            WHEN State IS NULL
              OR TRIM(State) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_State,

    SUM(
        CASE
            WHEN [Submitted via] IS NULL
              OR TRIM([Submitted via]) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Submitted_Via,

    SUM(
        CASE
            WHEN [Timely response?] IS NULL
              OR TRIM([Timely response?]) = ''
            THEN 1 ELSE 0
        END
    ) AS Missing_Timely_Response

FROM dbo.CFPB_Complaints_Staging;


/*====================================================================
    5. CHECK INVALID DATES
====================================================================*/

SELECT
    COUNT(*) AS Invalid_Date_Received
FROM dbo.CFPB_Complaints_Staging
WHERE NULLIF(TRIM([Date received]), '') IS NOT NULL
  AND TRY_CONVERT(
        datetime2(0),
        REPLACE(TRIM([Date received]), 'Z', ''),
        126
      ) IS NULL;


SELECT
    COUNT(*) AS Invalid_Date_Sent
FROM dbo.CFPB_Complaints_Staging
WHERE NULLIF(TRIM([Date sent to company]), '') IS NOT NULL
  AND TRY_CONVERT(
        datetime2(0),
        REPLACE(TRIM([Date sent to company]), 'Z', ''),
        126
      ) IS NULL;


/*====================================================================
    6. CHECK CATEGORY VALUES
====================================================================*/

-- Product

SELECT
    Product,
    COUNT(*) AS Complaint_Count
FROM dbo.CFPB_Complaints_Staging
GROUP BY Product
ORDER BY Complaint_Count DESC;


-- Issue

SELECT
    Issue,
    COUNT(*) AS Complaint_Count
FROM dbo.CFPB_Complaints_Staging
GROUP BY Issue
ORDER BY Complaint_Count DESC;


-- Submitted Via

SELECT
    [Submitted via],
    COUNT(*) AS Complaint_Count
FROM dbo.CFPB_Complaints_Staging
GROUP BY [Submitted via]
ORDER BY Complaint_Count DESC;


-- Timely Response

SELECT
    [Timely response?],
    COUNT(*) AS Complaint_Count
FROM dbo.CFPB_Complaints_Staging
GROUP BY [Timely response?]
ORDER BY Complaint_Count DESC;


-- Company Response

SELECT
    [Company response to consumer],
    COUNT(*) AS Complaint_Count
FROM dbo.CFPB_Complaints_Staging
GROUP BY [Company response to consumer]
ORDER BY Complaint_Count DESC;


/*====================================================================
    7. CREATE CLEAN REPORTING TABLE
===================================================================*/

IF OBJECT_ID('dbo.CFPB_Complaints_Clean', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.CFPB_Complaints_Clean;
END;
GO


SELECT

    /*--------------------------------------------------------------
        Complaint ID
    --------------------------------------------------------------*/

    NULLIF(TRIM([Complaint ID]), '') AS [Complaint ID],


    /*--------------------------------------------------------------
        Dates
    --------------------------------------------------------------*/

    TRY_CONVERT(
        datetime2(0),
        REPLACE(TRIM([Date received]), 'Z', ''),
        126
    ) AS [Date Received],

    TRY_CONVERT(
        datetime2(0),
        REPLACE(TRIM([Date sent to company]), 'Z', ''),
        126
    ) AS [Date Sent to Company],


    /*--------------------------------------------------------------
        Product hierarchy
    --------------------------------------------------------------*/

    COALESCE(
        NULLIF(TRIM(Product), ''),
        'Unknown'
    ) AS Product,

    COALESCE(
        NULLIF(TRIM([Sub-product]), ''),
        'Unknown'
    ) AS [Sub-product],

    COALESCE(
        NULLIF(TRIM(Issue), ''),
        'Unknown'
    ) AS Issue,

    COALESCE(
        NULLIF(TRIM([Sub-issue]), ''),
        'Unknown'
    ) AS [Sub-issue],


    /*--------------------------------------------------------------
        Company
    --------------------------------------------------------------*/

    COALESCE(
        NULLIF(TRIM(Company), ''),
        'Unknown'
    ) AS Company,


    /*--------------------------------------------------------------
        Geography
    --------------------------------------------------------------*/

    COALESCE(
        NULLIF(UPPER(TRIM(State)), ''),
        'Unknown'
    ) AS State,

    NULLIF(TRIM([ZIP code]), '') AS [ZIP Code],


    /*--------------------------------------------------------------
        Submission channel
    --------------------------------------------------------------*/

    COALESCE(
        NULLIF(TRIM([Submitted via]), ''),
        'Unknown'
    ) AS [Submitted Via],


    /*--------------------------------------------------------------
        Company response
    --------------------------------------------------------------*/

    COALESCE(
        NULLIF(TRIM([Company response to consumer]), ''),
        'Unknown'
    ) AS [Company Response to Consumer],


    /*--------------------------------------------------------------
        Timely response
    --------------------------------------------------------------*/

    CASE
        WHEN UPPER(TRIM([Timely response?])) = 'YES'
            THEN 'Yes'

        WHEN UPPER(TRIM([Timely response?])) = 'NO'
            THEN 'No'

        ELSE 'Unknown'
    END AS [Timely Response]

INTO dbo.CFPB_Complaints_Clean

FROM dbo.CFPB_Complaints_Staging;

GO


/*====================================================================
    8. VERIFY CLEAN TABLE
====================================================================*/

SELECT COUNT(*) AS Clean_Row_Count
FROM dbo.CFPB_Complaints_Clean;


SELECT TOP 20 *
FROM dbo.CFPB_Complaints_Clean;


/*====================================================================
    9. VERIFY CLEAN DATA QUALITY
====================================================================*/

SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT [Complaint ID]) AS Unique_Complaints,

    SUM(
        CASE
            WHEN [Complaint ID] IS NULL
            THEN 1 ELSE 0
        END
    ) AS Missing_Complaint_ID,

    SUM(
        CASE
            WHEN Product = 'Unknown'
            THEN 1 ELSE 0
        END
    ) AS Unknown_Product,

    SUM(
        CASE
            WHEN [Sub-product] = 'Unknown'
            THEN 1 ELSE 0
        END
    ) AS Unknown_Sub_Product,

    SUM(
        CASE
            WHEN Issue = 'Unknown'
            THEN 1 ELSE 0
        END
    ) AS Unknown_Issue,

    SUM(
        CASE
            WHEN [Sub-issue] = 'Unknown'
            THEN 1 ELSE 0
        END
    ) AS Unknown_Sub_Issue,

    SUM(
        CASE
            WHEN State = 'Unknown'
            THEN 1 ELSE 0
        END
    ) AS Unknown_State,

    SUM(
        CASE
            WHEN [Submitted Via] = 'Unknown'
            THEN 1 ELSE 0
        END
    ) AS Unknown_Submitted_Via,

    SUM(
        CASE
            WHEN [Timely Response] = 'Unknown'
            THEN 1 ELSE 0
        END
    ) AS Unknown_Timely_Response

FROM dbo.CFPB_Complaints_Clean;


/*====================================================================
    10. CREATE INDEXES
====================================================================*/

CREATE INDEX IX_CFPB_Clean_DateReceived
ON dbo.CFPB_Complaints_Clean ([Date Received]);

CREATE INDEX IX_CFPB_Clean_Product
ON dbo.CFPB_Complaints_Clean (Product);

CREATE INDEX IX_CFPB_Clean_Company
ON dbo.CFPB_Complaints_Clean (Company);

CREATE INDEX IX_CFPB_Clean_Issue
ON dbo.CFPB_Complaints_Clean (Issue);

CREATE INDEX IX_CFPB_Clean_TimelyResponse
ON dbo.CFPB_Complaints_Clean ([Timely Response]);

CREATE INDEX IX_CFPB_Clean_SubmittedVia
ON dbo.CFPB_Complaints_Clean ([Submitted Via]);

GO


/*====================================================================
    Q1. WHAT DOES OUR COMPLAINT PORTFOLIO LOOK LIKE?
====================================================================*/

SELECT
    COUNT(*) AS Total_Complaints,
    COUNT(DISTINCT [Complaint ID]) AS Unique_Complaints,
    COUNT(DISTINCT Company) AS Companies,
    COUNT(DISTINCT Product) AS Products,
    COUNT(DISTINCT State) AS States
FROM dbo.CFPB_Complaints_Clean;


/*====================================================================
    Q2. WHICH FINANCIAL PRODUCTS GENERATE THE MOST COMPLAINTS,
        AND HOW HAS COMPLAINT VOLUME CHANGED OVER TIME?
====================================================================*/


-- Yearly complaint volume by product

SELECT
    YEAR([Date Received]) AS Complaint_Year,
    Product,
    COUNT(*) AS Complaint_Count
FROM dbo.CFPB_Complaints_Clean
WHERE [Date Received] IS NOT NULL
GROUP BY
    YEAR([Date Received]),
    Product
ORDER BY
    Complaint_Year,
    Complaint_Count DESC;

-- Monthly complaint volume by product

SELECT
    DATEFROMPARTS(
        YEAR([Date Received]),
        MONTH([Date Received]),
        1
    ) AS Complaint_Month,
    Product,
    COUNT(*) AS Complaint_Count
FROM dbo.CFPB_Complaints_Clean
WHERE [Date Received] IS NOT NULL
GROUP BY
    DATEFROMPARTS(
        YEAR([Date Received]),
        MONTH([Date Received]),
        1
    ),
    Product
ORDER BY
    Complaint_Month;


/*====================================================================
    Q3. WHICH SPECIFIC ISSUES ARE RESPONSIBLE FOR THE LARGEST
        SHARE OF COMPLAINTS WITHIN EACH PRODUCT?
====================================================================*/

WITH Issue_Counts AS
(
    SELECT
        Product,
        Issue,
        COUNT(*) AS Complaint_Count
    FROM dbo.CFPB_Complaints_Clean
    GROUP BY
        Product,
        Issue
),
Ranked AS
(
    SELECT
        Product,
        Issue,
        Complaint_Count,
        ROW_NUMBER() OVER
        (
            PARTITION BY Product
            ORDER BY Complaint_Count DESC
        ) AS Issue_Rank
    FROM Issue_Counts
)

SELECT
    Product,
    Issue,
    Complaint_Count,
    Issue_Rank
FROM Ranked
WHERE Issue_Rank <= 5
ORDER BY
    Product,
    Issue_Rank;

/*====================================================================
    Q4. WHICH COMPANIES HAVE UNUSUALLY HIGH COMPLAINT VOLUMES
        RELATIVE TO THEIR OVERALL COMPLAINT PORTFOLIO?
====================================================================*/

WITH Company_Product AS
(
    SELECT
        Company,
        Product,
        COUNT(*) AS Complaints
    FROM dbo.CFPB_Complaints_Clean
    GROUP BY
        Company,
        Product
),

Company_Total AS
(
    SELECT
        Company,
        SUM(Complaints) AS Total_Complaints
    FROM Company_Product
    GROUP BY Company
)

SELECT
    cp.Company,
    cp.Product,
    cp.Complaints,
    ct.Total_Complaints,
    CAST(
        100.0 * cp.Complaints
        / NULLIF(ct.Total_Complaints, 0)
        AS DECIMAL(10,2)
    ) AS Product_Share_Pct
FROM Company_Product cp
JOIN Company_Total ct
    ON cp.Company = ct.Company
ORDER BY
    cp.Company,
    Product_Share_Pct DESC;


/*====================================================================
    Q5. WHICH COMPANIES HAVE THE WEAKEST
        TIMELY-RESPONSE PERFORMANCE?
====================================================================*/

SELECT
    Company,
    COUNT(*) AS Complaints_Sent_To_Company,
    SUM(
        CASE
            WHEN [Timely Response] = 'Yes'
            THEN 1
            ELSE 0
        END
    ) AS Timely_Responses,
    SUM(
        CASE
            WHEN [Timely Response] = 'No'
            THEN 1
            ELSE 0
        END
    ) AS Untimely_Responses,
    CAST(
        100.0 *
        SUM(
            CASE
                WHEN [Timely Response] = 'Yes'
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN [Timely Response] IN ('Yes', 'No')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        )
        AS DECIMAL(10,2)
    ) AS Timely_Response_Rate
FROM dbo.CFPB_Complaints_Clean
GROUP BY Company
HAVING
    COUNT(*) >= 100
ORDER BY
    Timely_Response_Rate ASC;


/*====================================================================
    Q6. WHICH COMPLAINT ISSUES ARE MOST ASSOCIATED
        WITH UNTIMELY RESPONSES?
====================================================================*/

SELECT
    Issue,
    COUNT(*) AS Complaints,
    SUM(
        CASE
            WHEN [Timely Response] = 'No'
            THEN 1
            ELSE 0
        END
    ) AS Untimely,
    CAST(
        100.0 *
        SUM(
            CASE
                WHEN [Timely Response] = 'No'
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Untimely_Rate
FROM dbo.CFPB_Complaints_Clean
WHERE [Timely Response] IN ('Yes', 'No')
GROUP BY Issue
HAVING COUNT(*) >= 100
ORDER BY
    Untimely_Rate DESC;


/*====================================================================
    Q7. ARE CERTAIN COMPLAINT SUBMISSION CHANNELS ASSOCIATED
        WITH DIFFERENT RESPONSE PERFORMANCE?
====================================================================*/

SELECT
    [Submitted Via],
    COUNT(*) AS Complaints,
    SUM(
        CASE
            WHEN [Timely Response] = 'Yes'
            THEN 1
            ELSE 0
        END
    ) AS Timely,
    SUM(
        CASE
            WHEN [Timely Response] = 'No'
            THEN 1
            ELSE 0
        END
    ) AS Untimely,
    CAST(
        100.0 *
        SUM(
            CASE
                WHEN [Timely Response] = 'Yes'
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN [Timely Response] IN ('Yes', 'No')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        )
        AS DECIMAL(10,2)
    ) AS Timely_Response_Rate
FROM dbo.CFPB_Complaints_Clean
GROUP BY [Submitted Via]
ORDER BY
    Timely_Response_Rate DESC;


/*====================================================================
    Q8. WHICH PRODUCT-ISSUE COMBINATIONS ARE BECOMING
        INCREASINGLY IMPORTANT OVER TIME?
====================================================================*/

WITH Monthly AS
(
    SELECT
        Product,
        Issue,
        DATEFROMPARTS(
            YEAR([Date Received]),
            MONTH([Date Received]),
            1
        ) AS Complaint_Month,
        COUNT(*) AS Complaints
    FROM dbo.CFPB_Complaints_Clean
    WHERE [Date Received] IS NOT NULL
    GROUP BY
        Product,
        Issue,
        DATEFROMPARTS(
            YEAR([Date Received]),
            MONTH([Date Received]),
            1
        )
),
Growth AS
(
    SELECT
        Product,
        Issue,
        Complaint_Month,
        Complaints,
        LAG(Complaints) OVER
        (
            PARTITION BY Product, Issue
            ORDER BY Complaint_Month
        ) AS Previous_Month
    FROM Monthly
)

SELECT
    Product,
    Issue,
    Complaint_Month,
    Complaints,
    Previous_Month,
    Complaints - Previous_Month
        AS Change_From_Previous_Month,
    CAST(
        100.0 *
        (Complaints - Previous_Month)
        /
        NULLIF(Previous_Month, 0)
        AS DECIMAL(10,2)
    ) AS Pct_Change
FROM Growth
WHERE Previous_Month IS NOT NULL
ORDER BY
    Pct_Change DESC;


/*====================================================================
    Q9. WHICH PRODUCT-ISSUE COMBINATIONS SHOULD MANAGEMENT
        PRIORITIZE BASED ON BOTH COMPLAINT VOLUME AND
        RESPONSE PERFORMANCE?
====================================================================*/


-- Basic volume + response performance

SELECT
    Product,
    Issue,
    COUNT(*) AS Complaints,
    SUM(
        CASE
            WHEN [Timely Response] = 'No'
            THEN 1
            ELSE 0
        END
    ) AS Untimely_Responses,
    CAST(
        100.0 *
        SUM(
            CASE
                WHEN [Timely Response] = 'No'
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Untimely_Rate
FROM dbo.CFPB_Complaints_Clean
WHERE [Timely Response] IN ('Yes', 'No')
GROUP BY
    Product,
    Issue
HAVING COUNT(*) >= 100
ORDER BY
    Complaints DESC,
    Untimely_Rate DESC;


/*--------------------------------------------------------------------
    Q9 PRIORITY CLASSIFICATION

    75th percentile is used to identify:
        - High Volume
        - Response Risk
        - High Priority
--------------------------------------------------------------------*/

WITH Metrics AS
(
    SELECT
        Product,
        Issue,
        COUNT(*) AS Complaints,
        CAST(
            100.0 *
            SUM(
                CASE
                    WHEN [Timely Response] = 'No'
                    THEN 1
                    ELSE 0
                END
            )
            /
            NULLIF(COUNT(*), 0)
            AS DECIMAL(10,2)
        ) AS Untimely_Rate
    FROM dbo.CFPB_Complaints_Clean
    WHERE [Timely Response] IN ('Yes', 'No')
    GROUP BY
        Product,
        Issue
    HAVING COUNT(*) >= 100
),
Benchmarks AS
(
    SELECT
        *,
        PERCENTILE_CONT(0.75)
        WITHIN GROUP
        (
            ORDER BY Complaints
        )
        OVER () AS Volume_75th,
        PERCENTILE_CONT(0.75)
        WITHIN GROUP
        (
            ORDER BY Untimely_Rate
        )
        OVER () AS Untimely_75th
    FROM Metrics
)

SELECT
    Product,
    Issue,
    Complaints,
    Untimely_Rate,
    CASE
        WHEN Complaints >= Volume_75th
         AND Untimely_Rate >= Untimely_75th
            THEN 'HIGH PRIORITY'
        WHEN Complaints >= Volume_75th
            THEN 'HIGH VOLUME'
        WHEN Untimely_Rate >= Untimely_75th
            THEN 'RESPONSE RISK'
        ELSE 'LOWER PRIORITY'
    END AS Priority
FROM Benchmarks
ORDER BY
    Complaints DESC;


/*====================================================================
    Q10. WHICH COMPANIES HAVE THE GREATEST COMPLAINT-RESPONSE
         RISK AFTER ACCOUNTING FOR THE TYPES OF PRODUCTS
         THEY HANDLE?

    Method:
        1. Calculate company-product complaint volume.
        2. Calculate product-level untimely benchmark.
        3. Calculate each company's actual untimely rate.
        4. Calculate expected untimely rate based on product mix.
        5. Calculate risk gap:

             Actual Untimely Rate
                  -
             Expected Untimely Rate

        A positive gap means the company performs worse than
        expected given its product mix.
====================================================================*/

WITH Company_Product AS
(
    SELECT
        Company,
        Product,
        COUNT(*) AS Complaints,
        SUM(
            CASE
                WHEN [Timely Response] = 'No'
                THEN 1
                ELSE 0
            END
        ) AS Untimely

    FROM dbo.CFPB_Complaints_Clean
    WHERE [Timely Response] IN ('Yes', 'No')
    GROUP BY
        Company,
        Product
),

Product_Benchmark AS
(
    SELECT
        Product,
        CAST(
            100.0 *
            SUM(Untimely)
            /
            NULLIF(SUM(Complaints), 0)
            AS DECIMAL(10,2)
        ) AS Product_Untimely_Rate
    FROM Company_Product
    GROUP BY Product
),

Company_Risk AS
(
    SELECT
        cp.Company,
        SUM(cp.Complaints) AS Total_Complaints,
        SUM(cp.Untimely) AS Total_Untimely,
        CAST(
            100.0 *
            SUM(cp.Untimely)
            /
            NULLIF(SUM(cp.Complaints), 0)
            AS DECIMAL(10,2)
        ) AS Actual_Untimely_Rate,
        CAST(
            SUM(
                cp.Complaints
                * pb.Product_Untimely_Rate
                / 100.0
            )
            /
            NULLIF(SUM(cp.Complaints), 0)
            AS DECIMAL(10,2)
        ) AS Expected_Untimely_Rate
    FROM Company_Product cp
    JOIN Product_Benchmark pb
        ON cp.Product = pb.Product
    GROUP BY
        cp.Company
    HAVING
        SUM(cp.Complaints) >= 500
)

SELECT
    Company,
    Total_Complaints,
    Total_Untimely,
    Actual_Untimely_Rate,
    Expected_Untimely_Rate,
    CAST(
        Actual_Untimely_Rate
        - Expected_Untimely_Rate
        AS DECIMAL(10,2)
    ) AS Risk_Gap_Pct,
    CASE
        WHEN Actual_Untimely_Rate
             - Expected_Untimely_Rate >= 5
            THEN 'HIGH RISK'
        WHEN Actual_Untimely_Rate
            - Expected_Untimely_Rate >= 2
            THEN 'MODERATE RISK'
        WHEN Actual_Untimely_Rate
            - Expected_Untimely_Rate > 0
            THEN 'SLIGHTLY ABOVE EXPECTED'
        ELSE 'AT OR BELOW EXPECTED'
    END AS Risk_Category
FROM Company_Risk
ORDER BY
    Risk_Gap_Pct DESC;


/*====================================================================
    11. FINAL DATASET CHECK 
====================================================================*/

SELECT
    COUNT(*) AS Total_Complaints,
    MIN([Date Received]) AS Earliest_Complaint_Date,
    MAX([Date Received]) AS Latest_Complaint_Date,
    COUNT(DISTINCT Product) AS Product_Count,
    COUNT(DISTINCT Issue) AS Issue_Count,
    COUNT(DISTINCT Company) AS Company_Count,
    COUNT(DISTINCT State) AS State_Count,
    COUNT(DISTINCT [Submitted Via]) AS Channel_Count
FROM dbo.CFPB_Complaints_Clean;

