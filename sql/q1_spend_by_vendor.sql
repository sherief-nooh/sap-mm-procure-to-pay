-- Q1. Spend by vendor (Pareto analysis)
-- Question: Where does our purchasing money go?
-- Method:   PO value = quantity x net price / price unit (EKPO),
--           joined to the PO header (EKKO) and vendor master (LFA1).
--           A running total shows how many vendors make up 80% of spend.
-- Finding:  11 of 21 vendors account for 80% of total PO value.
-- Action:   Focus annual contracts and price negotiations on these 11 vendors.

WITH spend AS (
    SELECT k.LIFNR, v.NAME1, v.LAND1,
           ROUND(SUM(p.MENGE * p.NETPR / p.PEINH), 0) AS po_value_aed,
           COUNT(DISTINCT k.EBELN)                    AS po_count
    FROM EKKO k
    JOIN EKPO p ON p.EBELN = k.EBELN
    JOIN LFA1 v ON v.LIFNR = k.LIFNR
    GROUP BY k.LIFNR, v.NAME1, v.LAND1
)
SELECT NAME1 AS vendor, LAND1 AS country, po_count, po_value_aed,
       ROUND(100.0 * po_value_aed / SUM(po_value_aed) OVER (), 1) AS share_pct,
       ROUND(100.0 * SUM(po_value_aed) OVER (ORDER BY po_value_aed DESC)
             / SUM(po_value_aed) OVER (), 1) AS running_share_pct
FROM spend
ORDER BY po_value_aed DESC;