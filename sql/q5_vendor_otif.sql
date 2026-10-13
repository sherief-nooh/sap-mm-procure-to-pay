-- Q5. Vendor delivery performance (OTIF)
-- Question: Which vendors deliver on time and in full?
-- Method:   First goods receipt date (MSEG, movement type 101) compared with
--           the agreed delivery date (EKET.EINDT). Received quantity compared
--           with ordered quantity (EKPO.MENGE). OTIF = on time AND in full.
--           Only vendors with 20+ delivered lines are shown.
-- Finding:  Fleet-wide OTIF is 70%. Shenzhen Auto Components is lowest at 45%:
--           in full 96% of the time, but on time only 48%. The problem is lead
--           time, not quantity. Hamburg Hydraulics and Delta Spare Parts lead at 91%.
-- Action:   Review lead times with the bottom 5 vendors, add buffer days to import
--           POs, and move volume toward the top performers where possible.

WITH gr AS (
    SELECT EBELN, EBELP, MIN(BUDAT) AS first_gr, SUM(MENGE) AS gr_qty
    FROM MSEG
    WHERE BWART = '101'
    GROUP BY EBELN, EBELP
)
SELECT v.NAME1 AS vendor, v.LAND1 AS country,
       COUNT(*) AS delivered_lines,
       ROUND(100.0 * AVG(g.first_gr <= e.EINDT), 1)                         AS on_time_pct,
       ROUND(100.0 * AVG(g.gr_qty >= p.MENGE), 1)                           AS in_full_pct,
       ROUND(100.0 * AVG(g.first_gr <= e.EINDT AND g.gr_qty >= p.MENGE), 1) AS otif_pct,
       ROUND(AVG(MAX(julianday(g.first_gr) - julianday(e.EINDT), 0)), 1)     AS avg_days_late
FROM gr g
JOIN EKPO p ON p.EBELN = g.EBELN AND p.EBELP = g.EBELP
JOIN EKET e ON e.EBELN = g.EBELN AND e.EBELP = g.EBELP
JOIN EKKO k ON k.EBELN = g.EBELN
JOIN LFA1 v ON v.LIFNR = k.LIFNR
GROUP BY v.NAME1, v.LAND1
HAVING COUNT(*) >= 20
ORDER BY otif_pct ASC;