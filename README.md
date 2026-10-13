# SAP MM Procure-to-Pay Analysis

SQL analysis of a full procure-to-pay cycle, built on the **SAP MM data model**: purchase requisitions, purchase orders, goods receipts and vendor invoices, using SAP table and field names (`EBAN`, `EKKO`, `EKPO`, `EKET`, `MSEG`, `RSEG`, `LFA1`, `MARA`).

The questions are the ones a procurement manager asks every month: where does the money go, which vendors deliver, which invoices should not be paid, and what is stuck.

> **About the data:** synthetic data shaped like SAP MM table extracts (SE16N-style), not a live SAP system. One company code, one plant, AED, October 2025 to September 2026. Approval controls were tightened in April 2026, so several results compare before and after.

## The procure-to-pay flow

| Step | SAP transaction | Table |
|---|---|---|
| Purchase requisition | ME51N | `EBAN` |
| Purchase order | ME21N | `EKKO` header, `EKPO` items, `EKET` delivery dates |
| Goods receipt | MIGO (movement 101, return 122) | `MSEG` |
| Invoice | MIRO | `RSEG` |
| Master data | XK03 / MM03 | `LFA1` vendors, `MARA` materials |

| Table | Rows |
|---|---:|
| `LFA1` vendors | 25 |
| `MARA` materials | 76 |
| `EBAN` requisition items | 2,002 |
| `EKKO` purchase orders | 1,150 |
| `EKPO` PO items | 2,326 |
| `MSEG` goods movements | 2,340 |
| `RSEG` invoice items | 2,276 |

Field-by-field reference: [`docs/sap_tables_and_tcodes.md`](docs/sap_tables_and_tcodes.md)

## Findings

| # | Question | Finding |
|---|---|---|
| Q1 | Where does the money go? | **11 of 21 vendors make up 80% of spend** (AED 24.3M total). These are the vendors to put on annual contracts. |
| Q2 | Which categories? | Lubricants, engine parts and hydraulics take **57% of spend**. Office supplies rank 5th, above brakes and filters, which is worth a review. |
| Q3 | How long from request to order? | Average requisition-to-PO time fell from **7.6 to 3.5 days**; the longest wait from 38 to 16 days. |
| Q4 | How much buying skips approval? | PO lines without a requisition fell from **19.6% to 5.8%** after April (AED 2.65M → AED 0.80M). |
| Q5 | Which vendors deliver on time and in full? | Overall OTIF is **70%**. The weakest vendor delivers in full 96% of the time but on time only 48%: a lead-time problem, not a quantity problem. |
| Q6 | Which invoices should not be paid as they are? | **256 of 2,276 invoice lines (11%)** fail the three-way match, **AED 352K at risk**: 187 priced above the PO, 65 billed for more than was received. |
| Q7 | Which vendors cause invoice problems? | **Delta Spare Parts has the highest exception rate (32%)** while being the second-best vendor on delivery (91% OTIF). Delivery and invoicing have to be scored separately. |
| Q8 | What is overdue? | **49 PO lines worth AED 365K** have passed their delivery date with no receipt; 41 are more than 90 days late. |

## Three-way match (Q6)

Before an invoice is paid, three documents should agree:

1. **Purchase order** (`EKPO`): the agreed quantity and price
2. **Goods receipt** (`MSEG`): what arrived, net of returns (101 minus 122)
3. **Invoice** (`RSEG`): what the vendor charges

An invoice line is flagged when it bills more than was received, or at a price more than 2% above the PO.

```sql
WITH gr AS (
    SELECT EBELN, EBELP,
           SUM(CASE WHEN BWART = '101' THEN MENGE ELSE -MENGE END) AS net_gr_qty
    FROM MSEG
    GROUP BY EBELN, EBELP
)
SELECT i.BELNR AS invoice, i.EBELN AS po, v.NAME1 AS vendor,
       p.MENGE AS po_qty, g.net_gr_qty AS gr_qty, i.MENGE AS inv_qty,
       p.NETPR AS po_price, ROUND(i.WRBTR / i.MENGE, 2) AS inv_price
FROM RSEG i
JOIN EKPO p ON p.EBELN = i.EBELN AND p.EBELP = i.EBELP
JOIN gr   g ON g.EBELN = i.EBELN AND g.EBELP = i.EBELP
JOIN LFA1 v ON v.LIFNR = i.LIFNR
WHERE i.MENGE > g.net_gr_qty
   OR (i.WRBTR / i.MENGE) > p.NETPR * 1.02;
```

Example from the results: a vendor ordered for 200 units delivered 122 and invoiced 200, an overcharge of AED 12,626 that the match catches before payment.

## Files

```text
├── sap_mm_p2p.db          SQLite database with all eight tables
├── queries.sql            All eight queries in one file
├── sql/                   One file per question, each with question, method, finding and action
├── results/               Output of each query (CSV)
├── data/                  The eight tables as CSV
└── docs/
    └── sap_tables_and_tcodes.md
```

## Run it

1. Install [DB Browser for SQLite](https://sqlitebrowser.org) (free).
2. Open `sap_mm_p2p.db`.
3. Open any file from `sql/` in the **Execute SQL** tab and run it.

SQL used: joins across header and item tables, CTEs, window functions for running totals (`SUM() OVER`), conditional aggregation (`SUM(CASE WHEN ...)`), and `LEFT JOIN ... IS NULL` to find orders with no receipt.

## About

Built by **Sherief Nooh**, supply chain, logistics and security operations professional, FIATA Higher Diploma in Supply Chain Management.

[Portfolio](https://sherief-nooh.github.io) · [LinkedIn](https://www.linkedin.com/in/sherief-nouh/) · [GitHub](https://github.com/sherief-nooh)
