-- Q6. Three-way match exceptions (PO vs goods receipt vs invoice)
-- Question: Which invoices charge more than we received or agreed?
-- Method:   Invoice lines (RSEG) compared with the PO price (EKPO.NETPR) and
--           the net received quantity (MSEG: 101 receipts minus 122 returns).
--           Flagged when invoiced qty > received qty, or invoice price is
--           more than 2% above the PO price.
-- Finding:  256 of 2,276 invoice lines (11%) are exceptions, AED 352K at risk.
--           187 are price above PO (AED 176K), 65 are quantity above receipt
--           (AED 165K), 4 are both.
-- Action:   Block these invoices for payment until resolved (in SAP: payment
--           block in MIRO, released in MRBR), and recover the overcharge.
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