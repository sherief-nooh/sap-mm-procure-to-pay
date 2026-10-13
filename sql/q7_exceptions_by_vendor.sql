-- Q7. Three-way match exceptions by vendor
-- Question: Which vendors cause the most invoice problems?
-- Method:   Same rules as Q6 (invoiced qty above received qty, or price more
--           than 2% above PO), summarised per vendor.
-- Finding:  Delta Spare Parts has the highest exception rate (32% of invoices)
--           even though it is the second-best vendor on delivery (91% OTIF).
--           Gulf Auto Parts has the most money at risk (AED 50K).
-- Action:   Delivery and invoicing must be scored separately. Ask Delta Spare
--           Parts to align invoice prices with the PO, and review Gulf Auto
--           Parts invoices before payment.
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