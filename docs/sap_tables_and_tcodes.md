# SAP MM tables and transactions used in this project

The procure-to-pay flow in SAP MM, and where each step is stored:

| Step | Transaction | What happens | Table(s) |
|---|---|---|---|
| 1. Purchase requisition | ME51N | A department asks to buy something | `EBAN` |
| 2. Purchase order | ME21N | Purchasing orders it from a vendor | `EKKO` (header), `EKPO` (items), `EKET` (delivery dates) |
| 3. Goods receipt | MIGO, movement type 101 | The warehouse receives the goods | `MSEG` (`MKPF` header) |
| 3b. Return to vendor | MIGO, movement type 122 | Goods sent back | `MSEG` |
| 4. Invoice receipt | MIRO | Accounts payable posts the vendor invoice | `RSEG` (`RBKP` header) |
| Reports | ME2N, ME80FN, MB51, MB52 | PO list, PO history, material documents, stock | |

Master data: `LFA1` vendors (XK03), `MARA` materials (MM03).

## Fields

### LFA1 (vendor master)
| Field | Meaning |
|---|---|
| LIFNR | Vendor number |
| NAME1 | Vendor name |
| LAND1 | Country |
| ORT01 | City |
| KTOKK | Account group (LIEF local, IMPO import) |

### MARA (material master, with text and standard price)
| Field | Meaning |
|---|---|
| MATNR | Material number |
| MAKTX | Material description (from MAKT) |
| MATKL | Material group |
| MEINS | Base unit (EA each, L litre) |
| STPRS | Standard price, AED (from MBEW) |

### EBAN (purchase requisition)
| Field | Meaning |
|---|---|
| BANFN / BNFPO | Requisition number / item |
| MATNR, MENGE, MEINS | Material, quantity, unit |
| BADAT | Requisition date |
| WERKS | Plant |

### EKKO (PO header) and EKPO (PO item)
| Field | Meaning |
|---|---|
| EBELN / EBELP | PO number / item |
| LIFNR | Vendor |
| BEDAT | PO date |
| BSART | Document type (NB standard PO) |
| BUKRS, EKGRP | Company code, purchasing group |
| MATNR, TXZ01, MATKL | Material, short text, material group |
| MENGE, NETPR, PEINH | Quantity, net price, price unit |
| BANFN / BNFPO | Requisition the PO came from (empty = no requisition) |

### EKET (delivery schedule)
| Field | Meaning |
|---|---|
| EINDT | Agreed delivery date |

### MSEG (material document items)
| Field | Meaning |
|---|---|
| MBLNR / MJAHR / ZEILE | Material document / year / line |
| BWART | Movement type (101 GR for PO, 122 return to vendor) |
| MENGE | Quantity |
| EBELN / EBELP | PO reference |
| BUDAT | Posting date |
| WERKS, LGORT | Plant, storage location |

### RSEG (invoice items)
| Field | Meaning |
|---|---|
| BELNR / GJAHR / BUZEI | Invoice document / year / line |
| EBELN / EBELP | PO reference |
| MENGE | Invoiced quantity |
| WRBTR | Invoiced amount, AED |
| BLDAT | Invoice date |

## Three-way match

SAP compares three documents before an invoice is paid:

1. **PO** (`EKPO`): what we agreed to buy, at what price
2. **Goods receipt** (`MSEG`): what actually arrived
3. **Invoice** (`RSEG`): what the vendor is charging

An invoice is an exception when it charges for more than was received, or at a price above the PO (here, more than 2% above). In SAP these invoices are usually blocked for payment (MRBR to release).
