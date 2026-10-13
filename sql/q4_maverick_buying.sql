-- Q4. Maverick buying: PO lines raised without a purchase requisition
-- Question: How much buying skips the approval step?
-- Method:   PO lines (EKPO) with no requisition reference (BANFN is empty),
--           counted by PO month (EKKO.BEDAT).
-- Finding:  Before April 2026, 19.6% of PO lines had no requisition
--           (AED 2.65M of spend). After approval controls started in April,
--           this fell to 5.8% (AED 0.80M).
-- Action:   Block PO creation without a requisition for standard materials
--           (release strategy in SAP), and review the remaining exceptions monthly.
SELECT strftime('%Y-%m', k.BEDAT) AS month,
       COUNT(*) AS po_lines,
       SUM(CASE WHEN p.BANFN IS NULL THEN 1 ELSE 0 END) AS without_pr,
       ROUND(100.0 * SUM(CASE WHEN p.BANFN IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS without_pr_pct
FROM EKPO p
JOIN EKKO k ON k.EBELN = p.EBELN
GROUP BY month
ORDER BY month;