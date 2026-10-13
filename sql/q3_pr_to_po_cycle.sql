-- Q3. Requisition-to-PO cycle time, by quarter
-- Question: How long does a purchase request wait before it becomes an order?
-- Method:   Days between the requisition date (EBAN.BADAT) and the PO date
--           (EKKO.BEDAT), linked through EKPO.BANFN / BNFPO.
-- Finding:  Average cycle time fell from 7.6 days (Q4 2025) to 3.5 days
--           (Q3 2026) after approval steps were tightened in April 2026.
--           The longest wait fell from 38 days to 16.
-- Action:   Keep tracking the maximum, not only the average: a few requests
--           stuck for weeks hurt operations more than a one-day average change.

SELECT strftime('%Y', k.BEDAT) || '-Q' || ((CAST(strftime('%m', k.BEDAT) AS INT) + 2) / 3) AS quarter,
       COUNT(*) AS po_lines,
       ROUND(AVG(julianday(k.BEDAT) - julianday(r.BADAT)), 1) AS avg_days_pr_to_po,
       MAX(julianday(k.BEDAT) - julianday(r.BADAT))           AS max_days
FROM EKPO p
JOIN EKKO k ON k.EBELN = p.EBELN
JOIN EBAN r ON r.BANFN = p.BANFN AND r.BNFPO = p.BNFPO
GROUP BY quarter
ORDER BY quarter;