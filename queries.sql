-- =====================================================================
-- SAP MM Procure-to-Pay analysis
-- Database: sap_mm_p2p.db (SQLite). Run each query on its own.
-- Tables use SAP names: LFA1, MARA, EBAN, EKKO, EKPO, EKET, MSEG, RSEG
-- =====================================================================


-- Q1. Spend by vendor (PO value), with share of total and running share
--     Answers: where does the money go? Which vendors make up 80% of spend?
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


-- Q2. Spend by material group
SELECT p.MATKL AS material_group,
       COUNT(*) AS po_lines,
       ROUND(SUM(p.MENGE * p.NETPR / p.PEINH), 0) AS po_value_aed
FROM EKPO p
GROUP BY p.MATKL
ORDER BY po_value_aed DESC;


-- Q3. Requisition-to-PO cycle time (days), by quarter
--     EBAN.BADAT = requisition date, EKKO.BEDAT = PO date
SELECT strftime('%Y', k.BEDAT) || '-Q' || ((CAST(strftime('%m', k.BEDAT) AS INT) + 2) / 3) AS quarter,
       COUNT(*) AS po_lines,
       ROUND(AVG(julianday(k.BEDAT) - julianday(r.BADAT)), 1) AS avg_days_pr_to_po,
       MAX(julianday(k.BEDAT) - julianday(r.BADAT))           AS max_days
FROM EKPO p
JOIN EKKO k ON k.EBELN = p.EBELN
JOIN EBAN r ON r.BANFN = p.BANFN AND r.BNFPO = p.BNFPO
GROUP BY quarter
ORDER BY quarter;


-- Q4. Maverick buying: PO lines raised without a purchase requisition
SELECT strftime('%Y-%m', k.BEDAT) AS month,
       COUNT(*) AS po_lines,
       SUM(CASE WHEN p.BANFN IS NULL THEN 1 ELSE 0 END) AS without_pr,
       ROUND(100.0 * SUM(CASE WHEN p.BANFN IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS without_pr_pct
FROM EKPO p
JOIN EKKO k ON k.EBELN = p.EBELN
GROUP BY month
ORDER BY month;


-- Q5. Vendor delivery performance: on time (GR date <= delivery date)
--     and in full (received qty >= ordered qty). OTIF = both.
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


-- Q6. Three-way match exceptions: PO price vs invoice price, GR qty vs invoice qty
--     Flags: price variance above 2%, or invoiced quantity above received quantity
WITH gr AS (
    SELECT EBELN, EBELP,
           SUM(CASE WHEN BWART = '101' THEN MENGE ELSE -MENGE END) AS net_gr_qty
    FROM MSEG
    GROUP BY EBELN, EBELP
)
SELECT i.BELNR AS invoice, i.EBELN AS po, i.EBELP AS po_item, v.NAME1 AS vendor,
       p.MENGE AS po_qty, g.net_gr_qty AS gr_qty, i.MENGE AS inv_qty,
       p.NETPR AS po_price, ROUND(i.WRBTR / i.MENGE, 2) AS inv_price,
       ROUND(100.0 * (i.WRBTR / i.MENGE - p.NETPR) / p.NETPR, 1) AS price_var_pct,
       CASE
           WHEN i.MENGE > g.net_gr_qty AND (i.WRBTR / i.MENGE) > p.NETPR * 1.02 THEN 'Qty and price'
           WHEN i.MENGE > g.net_gr_qty THEN 'Qty above GR'
           ELSE 'Price above PO'
       END AS exception,
       ROUND(i.WRBTR - MIN(i.MENGE, g.net_gr_qty) * p.NETPR, 2) AS amount_at_risk_aed
FROM RSEG i
JOIN EKPO p ON p.EBELN = i.EBELN AND p.EBELP = i.EBELP
JOIN gr   g ON g.EBELN = i.EBELN AND g.EBELP = i.EBELP
JOIN LFA1 v ON v.LIFNR = i.LIFNR
WHERE i.MENGE > g.net_gr_qty
   OR (i.WRBTR / i.MENGE) > p.NETPR * 1.02
ORDER BY amount_at_risk_aed DESC;


-- Q7. Exceptions summary by vendor (from Q6 logic)
WITH gr AS (
    SELECT EBELN, EBELP,
           SUM(CASE WHEN BWART = '101' THEN MENGE ELSE -MENGE END) AS net_gr_qty
    FROM MSEG GROUP BY EBELN, EBELP
), inv AS (
    SELECT i.LIFNR,
           (i.MENGE > g.net_gr_qty OR (i.WRBTR / i.MENGE) > p.NETPR * 1.02) AS is_exception,
           MAX(i.WRBTR - MIN(i.MENGE, g.net_gr_qty) * p.NETPR, 0)            AS at_risk
    FROM RSEG i
    JOIN EKPO p ON p.EBELN = i.EBELN AND p.EBELP = i.EBELP
    JOIN gr   g ON g.EBELN = i.EBELN AND g.EBELP = i.EBELP
)
SELECT v.NAME1 AS vendor, COUNT(*) AS invoices,
       SUM(is_exception) AS exceptions,
       ROUND(100.0 * SUM(is_exception) / COUNT(*), 1) AS exception_pct,
       ROUND(SUM(at_risk), 0) AS amount_at_risk_aed
FROM inv
JOIN LFA1 v ON v.LIFNR = inv.LIFNR
GROUP BY v.NAME1
ORDER BY amount_at_risk_aed DESC;


-- Q8. Open POs: ordered but not yet received, and overdue against delivery date
--     As-of date: 2026-09-30
SELECT k.EBELN AS po, p.EBELP AS item, v.NAME1 AS vendor, p.TXZ01 AS material,
       p.MENGE AS qty, e.EINDT AS due_date,
       CAST(julianday('2026-09-30') - julianday(e.EINDT) AS INT) AS days_overdue
FROM EKPO p
JOIN EKKO k ON k.EBELN = p.EBELN
JOIN EKET e ON e.EBELN = p.EBELN AND e.EBELP = p.EBELP
JOIN LFA1 v ON v.LIFNR = k.LIFNR
LEFT JOIN MSEG m ON m.EBELN = p.EBELN AND m.EBELP = p.EBELP AND m.BWART = '101'
WHERE m.MBLNR IS NULL AND e.EINDT < '2026-09-30'
ORDER BY days_overdue DESC;
