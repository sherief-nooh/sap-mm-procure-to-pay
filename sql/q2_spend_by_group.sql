-- Q2. Spend by material group
-- Question: Which categories of material take most of the budget?
-- Method:   PO value (EKPO: quantity x net price / price unit), grouped by
--           material group (EKPO.MATKL).
-- Finding:  Three groups take 57% of spend: lubricants (22%), engine spare
--           parts (19%) and hydraulic components (16%). Office supplies are
--           5th at 8.5%, more than brakes or filters, which is worth a review.
-- Action:   Put framework agreements in place for the top three groups, and
--           check office supply orders for non-standard or bulk buying.

SELECT p.MATKL AS material_group,
       COUNT(*) AS po_lines,
       ROUND(SUM(p.MENGE * p.NETPR / p.PEINH), 0) AS po_value_aed
FROM EKPO p
GROUP BY p.MATKL
ORDER BY po_value_aed DESC;