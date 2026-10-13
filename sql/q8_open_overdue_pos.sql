-- Q8. Open and overdue purchase orders
-- Question: What have we ordered that should have arrived but has not?
-- Method:   PO lines (EKPO) with no goods receipt (no MSEG 101) whose agreed
--           delivery date (EKET.EINDT) is before the as-of date, 30 Sep 2026.
-- Finding:  49 PO lines are overdue, worth AED 365K. 41 of them are more than
--           90 days late, which usually means the order is stuck or forgotten.
--           Gulf Auto Parts (7 lines) and Al Noor Tyres (6) have the most.
-- Action:   Chase or cancel lines older than 90 days (in SAP: ME2M / ME2N with
--           open-quantity selection), and close the PO so the budget is released.
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