#create database if not exists PLAN;
#use PLAN;

### Upload the data from `Data TEST-WhatsmyBill_ElectricityBill.xlsx` 

#select * from plan.plan_details; 




WITH SlabData AS (
SELECT *,
SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(pd.USAGERATESLAB, '|', n.n), '|', -1), ',', 1) AS SlabLimit,
CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(pd.USAGERATESLAB, '|', n.n), '|', -1), ',', -1) AS DECIMAL(10,2)) AS rate,
n.n AS SlabNumber
FROM plan_details pd JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7) AS n
WHERE n.n <= LENGTH(pd.USAGERATESLAB) - LENGTH(REPLACE(pd.USAGERATESLAB, '|', '')) + 1
) ,

SlabBoundaries AS 
(SELECT *,
(SELECT IFNULL(SUM(s2.SlabLimit), 0) FROM SlabData s2 WHERE s2.PLAN_ID = s1.PLAN_ID AND s2.SlabNumber < s1.SlabNumber) AS PreviousLimit
FROM SlabData s1
) ,

SlabRanges AS 
( SELECT *,PreviousLimit + SlabLimit AS CumulativeLimit FROM SlabBoundaries)  ,

SlabCharges AS 
(SELECT *,
CASE
WHEN PLAN_USAGE <= PreviousLimit THEN 0
WHEN PLAN_USAGE >= CumulativeLimit THEN SlabLimit * rate
ELSE (PLAN_USAGE - PreviousLimit) * rate
END AS SlabCharge
FROM SlabRanges
) ,

LastSlabAdjustment AS 
(SELECT*, (SELECT MAX(SlabNumber) FROM SlabRanges WHERE PLAN_ID = sr.PLAN_ID) AS MaxSlabNumber
FROM SlabRanges sr WHERE sr.SlabNumber = (SELECT MAX(SlabNumber) FROM SlabRanges WHERE PLAN_ID = sr.PLAN_ID)
AND sr.PLAN_USAGE > sr.CumulativeLimit
) ,

ExtraCharge AS 
(SELECT *,(PLAN_USAGE - CumulativeLimit) * rate AS ExtraSlabCharge FROM LastSlabAdjustment
) ,

TotalBill AS
(SELECT sc.PLAN_ID,sc.PLAN_NAME,sc.PLAN_USAGE, ROUND(SUM(sc.SlabCharge) + IFNULL(ec.ExtraSlabCharge, 0), 2) AS CalculatedBill
FROM SlabCharges sc LEFT JOIN ExtraCharge ec ON sc.PLAN_ID = ec.PLAN_ID
GROUP BY sc.PLAN_ID, sc.PLAN_NAME, sc.PLAN_USAGE, ec.ExtraSlabCharge
) 

SELECT pd.PLAN_ID, pd.PLAN_NAME, pd.USAGERATESLAB, pd.PLAN_USAGE, tb.CalculatedBill AS BILLVALUE
FROM plan_details pd LEFT JOIN TotalBill tb ON pd.PLAN_ID = tb.PLAN_ID;
