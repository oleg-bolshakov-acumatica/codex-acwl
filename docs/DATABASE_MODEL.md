# Acumatica ERP Database and Domain Model for Project & Construction Support

> **Generated from:** Acumatica ERP Pure Solution source code (DAC analysis)  
> **Branch:** 2026r250  
> **Purpose:** AI-friendly relational database and domain model for SQL-based support diagnostics

---

## 1. Purpose and Audience

This document is the **authoritative database-storage context** for AI agents investigating or reviewing **Project Accounting (PM), Construction (CN), and Project Management (PJ)** behavior in Acumatica ERP.

It connects the conceptual model from `docs/BUSINESS_MODEL.md` to the physical SQL tables, extension tables, projections, and cross-module join paths that store or derive project and construction state.

**It enables agents to:**

1. Understand the business/domain model used by Project and Construction.
2. Map business concepts to physical SQL database tables, extension tables, and projections.
3. Trace business flows across modules (PM ? AR ? AP ? PO ? IN ? GL ? EP ? SO).
4. Formulate and verify hypotheses using **read-only `SELECT` queries only**.
5. Identify likely data inconsistencies, missing joins, wrong assumptions, and common support workarounds.
6. Explain conclusions in domain language that support engineers and consultants understand.

This is **not** a business-model replacement and not a full ERP database catalog. It is a **deep, evidence-based technical reference** optimized for SQL-based hypothesis verification inside the Project and Construction domain.

---

## 2. Scope and Evidence Model

### Sources Analyzed

| Source | Description |
|---|---|
| DAC source code in PX.Objects.PM | PMProject, PMTask, PMBudget, PMTran, PMRegister, PMAccountGroup, PMCostCode, PMCommitment, PMChangeOrder, PMChangeOrderBudget, PMChangeOrderLine, PMChangeRequest, PMProforma, PMProformaLine, PMHistory, PMBillingRecord, PMForecastDetail, PMTaskTotal |
| DAC source code in PX.Objects | ARRegister, ARInvoice, ARPayment, ARTran, APRegister, APInvoice, APTran, SOOrder, SOLine, INRegister, Batch, GLTran, BAccount, Customer, Vendor |
| DAC source code in PX.Objects.CT | Contract (base class for PMProject) |
| DAC source code in PX.Objects.CN | Subcontract (projection over POOrder) |
| Local SQL definitions under `DatabaseModel/Application/PM` | Physical PM tables used for projects, budgets, transactions, billing, allocation, WIP, quotes, project files, and labor classifications |
| Local SQL definitions under `DatabaseModel/Application/CN` | Physical CN tables for compliance documents, lien waiver setup, joint payees, and construction references |
| Local SQL definitions under `DatabaseModel/Application/PJ` | Physical PJ tables for RFIs, project issues, daily field reports, drawings, photo logs, submittals, project contacts, and setup/status records |
| Acumatica Knowledge reference lookups | Optional cross-check for DAC summaries, field ownership, relationship discovery, and projection-vs-table classification |
| Status/type constant classes | ProjectStatus, ProjectTaskStatus, PMCommitmentType, ChangeOrderStatus, ProformaStatus, PMAccountType, PMBillingOption, PMCompletedPctMethod, BudgetLevels |
| FK/PK nested classes | Explicit `PK`, `FK`, `PXParent`, `PXForeignReference` declarations |
| PXProjection attributes | To distinguish physical tables from projections |

### Confidence Labeling Rules

| Label | Meaning |
|---|---|
| **explicit** | Confirmed by nested `FK` class, `PXForeignReference`, or `PXParent` attribute in source code |
| **strongly inferred** | Confirmed by `PXSelector`, `PXDefault(typeof(Search<...>))`, or release/processing code |
| **weakly inferred** | Based on naming conventions, field semantics, or typical Acumatica patterns; not explicitly enforced |
| **unconfirmed** | Mentioned for completeness; requires source verification |

### Persistence Classification Key

| Classification | Meaning | How to Identify |
|---|---|---|
| `physical_table` | Maps directly to a SQL Server table | DAC with `[PXDB*]` field attributes, no `[PXProjection]`, inherits `PXBqlTable` / `IBqlTable` |
| `extension_table` | Separate physical table sharing PK with base DAC | Has `[PXTable]` attribute on a derived DAC class |
| `projection` | BQL-defined view over one or more tables | Has `[PXProjection(...)]` attribute — **NOT a physical table** |
| `virtual` | No persisted fields; used for UI filters/processing | Only `[PXString]`/`[PXInt]` (without DB prefix) fields |

---

## 3. How to Use This Document

### Navigation Strategy for AI Support Agents

1. **Start from the business symptom** — identify which business concept is affected.
2. **Use Section 6** (Business Concept ? Database Mapping Matrix) to find the primary tables.
3. **Use Section 7** (Module-by-Module Database Model) to understand table structure and joins.
4. **Use Section 8** (Cross-Module Process Flows) to trace multi-step document flows.
5. **Use Section 9** (Canonical Join Maps) for exact SQL join patterns.
6. **Use Section 11** (SQL Verification Playbook) for symptom-specific diagnostic queries.
7. **Always validate** using Section 4 (Core Persistence and Querying Rules).

### Business Symptom ? SQL Verification Workflow

```
Customer reports issue
    ? Identify business process (billing? commitment? budget?)
    ? Find primary tables (PMBudget? PMCommitment? PMTran?)
    ? Determine join path to related tables
    ? Write SELECT query with CompanyID, compound keys
    ? Compare persisted values vs expected values
    ? Report findings with field-level evidence
```

### Additional Context Selection

Use this document to choose the physical storage starting point. Use additional sources only when they answer a question this document intentionally leaves compact:

- Use `docs/BUSINESS_MODEL.md` when the issue is about the business meaning of a Project, Quote, Budget, Commitment, Billing, Compliance, PJ document, or Project File.
- Use Acumatica Knowledge when exact DAC fields, field ownership, projections, API/OData/GI exposure, or related DAC discovery can change the join path.
- Use local source when release logic, workflow, graph processing, calculated fields, or persistence side effects determine how tables are updated.
- Use read-only SQL when tenant data, document lineage, balances, or environment-specific state must be confirmed.

---

## 4. Core Acumatica Persistence and Querying Rules

### CompanyID

- **Every physical table** has an implicit `CompanyID` column managed by the framework.
- It is **NOT** visible in DAC source code — the framework adds it automatically.
- **Raw SQL MUST include `CompanyID`** in all joins and WHERE clauses.
- Example: `JOIN PMTask ON PMBudget.CompanyID = PMTask.CompanyID AND PMBudget.ProjectID = PMTask.ProjectID AND PMBudget.ProjectTaskID = PMTask.TaskID`

### Compound Keys

Most Acumatica tables use **composite primary keys**:

| Pattern | Example |
|---|---|
| Single surrogate | PMProject: `ContractID` (identity) |
| Single GUID | PMCommitment: `CommitmentID` (GUID) |
| Single identity | PMTran: `TranID` (bigint identity) |
| Two-part composite | ARRegister: `DocType + RefNbr`, Batch: `Module + BatchNbr` |
| Multi-part composite | PMBudget: `ProjectID + ProjectTaskID + AccountGroupID + CostCodeID + InventoryID` (5-part) |
| Multi-part with identity | PMTask: `ProjectID + TaskID` where TaskID is identity |

**CRITICAL:** Never join on `RefNbr` alone without `DocType`, `OrderType`, or `Module`. Cross-type false matches will occur.

### Branch Filtering

- Many tables have a `BranchID` column.
- Branch-level security may restrict visibility.
- Include `BranchID` in queries when branch-level analysis is needed.

### Segmented Keys vs Surrogate IDs

| Entity | Surrogate ID (int) | Natural/Segmented Key (string) | Table Column Names |
|---|---|---|---|
| Project | ContractID | ContractCD | PMProject (via Contract base) |
| Task | TaskID | TaskCD | PMTask |
| Account Group | GroupID | GroupCD | PMAccountGroup |
| Cost Code | CostCodeID | CostCodeCD | PMCostCode |
| Inventory Item | InventoryID | InventoryCD | InventoryItem |
| Customer/Vendor | BAccountID | AcctCD | BAccount |
| GL Account | AccountID | AccountCD | Account |

**Rule:** Joins always use the **surrogate int ID**. The `*CD` fields are for human display only.

### Status Fields vs Boolean Flags

Status strings are often **derived from boolean flags**. The booleans are more reliable:

| Boolean Flags | Derived Status |
|---|---|
| `Hold = true` | Status = 'H' (On Hold) |
| `Approved = false, Hold = false` | Status = 'A' (Pending Approval) |
| `Released = true, OpenDoc = true` | Status = 'N' (Open) |
| `Released = true, OpenDoc = false` | Status = 'C' (Closed) |
| `Voided = true` | Status = 'V' (Voided) |

**Recommendation:** Filter on boolean flags rather than status strings where possible.

### Currency Fields: `Cury*` vs Base Currency

| Prefix/Pattern | Meaning |
|---|---|
| `Cury{Field}` (on AR/AP/SO documents) | Amount in **document currency** |
| `{Field}` (without prefix, on AR/AP/SO) | Amount in **base currency** of the company |
| `CuryAmount` (on PMBudget) | Amount in **project currency** |
| `Amount` (on PMBudget) | Amount in **base currency** of the tenant |
| `TranCuryAmount` (on PMTran) | Amount in **transaction currency** |
| `ProjectCuryAmount` (on PMTran) | Amount in **project currency** |
| `Amount` (on PMTran) | Amount in **base currency** |

**CRITICAL for PM:** PMBudget and PMHistory use **project currency** as the "Cury" layer. PMTran has **three currency layers**: transaction, project, and base.

### Extension Table Inheritance Pattern

AR/AP use a **split-table** pattern:
```
ARRegister (base: amounts, balances, status, customer, dates)
   ?? ARInvoice (extension: terms, tax, addresses, freight)
   ?? ARPayment (extension: payment method, cash account)
```

PM uses a different pattern — **Contract base table**:
```
Contract (base table in PX.Objects.CT — physical table)
   ?? PMProject (extension_table via [PXTable] — adds PM-specific fields)
```

PMProject inherits from Contract and uses `[PXTable]` to store additional fields. The `Contract` table holds the core persisted fields; the `PMProject` extension table holds PM-specific fields. **Both must be considered when querying project data.**

### Projection DACs Are NOT Physical Tables

**Common mistake:** Querying a projection DAC name as if it were a table.

Key PM projection example:
- `Subcontract` — `[PXProjection]` over `POOrder` where `OrderType = 'RS'` (regularSubcontract). **There is no `Subcontract` SQL table.** Query `POOrder` instead.

### NoteID, Audit Fields, and tstamp

| Column | Purpose |
|---|---|
| `NoteID` (guid) | Links to Note table for attachments, activities, full-text search |
| `CreatedByID` (guid) | Audit: who created ? Users table |
| `CreatedDateTime` | Audit: when created |
| `LastModifiedByID` (guid) | Audit: who last modified |
| `LastModifiedDateTime` | Audit: when last modified |
| `tstamp` | SQL `rowversion` for concurrency control |

---

## 5. Business Domain Model for Project & Construction

### Core Business Entities

#### Project (PMProject / Contract)
A planned set of related tasks executed over a fixed period within cost/revenue constraints. Every project consists of tasks, and its budget, profitability, and balances are monitored through account groups. Projects can be internal (no customer) or external (billable to a customer).

#### Project Task (PMTask)
The smallest identifiable unit of work within a project. Tasks are always defined within a project's scope. Each task has its own billing rule, allocation rule, billing option, and completion method. Budget lines are always associated with a task.

#### Cost Code (PMCostCode)
A classification code for project revenues and costs, primarily used in **construction projects**. Cost codes are associated with documents and document lines that reference projects. They add a dimension to the budget key beyond account group + task.

#### Account Group (PMAccountGroup)
A grouping mechanism for GL accounts that maps to project budget categories. Account groups have a type (Asset, Liability, Income, Expense, Off-Balance) and a reporting group (Labor, Material, Subcontract, Equipment, Other, Revenue). The type determines whether the account group appears on the cost budget or revenue budget tab.

#### Budget (PMBudget)
A budget line representing a planned amount for a specific combination of Project + Task + Account Group + Cost Code + Inventory Item. Budget lines track:
- **Original budgeted** amounts and quantities
- **Revised budgeted** amounts (original + change order adjustments)
- **Actual** amounts and quantities (from released transactions)
- **Committed** amounts (from PO/subcontract lines)
- **Change order** amounts (draft and approved)
- **Draft invoice** amounts (from unreleased proformas)
- **Pending invoice** amounts (amount to bill next)
- **Completion percentage** and **performance** metrics

Budget lines are differentiated by `Type`: `E` (Expense) for cost budget, `I` (Income) for revenue budget, and other GL account types.

#### Project Transaction (PMTran)
The fundamental transaction record for project accounting. PMTran records are created when:
- Financial documents are released (AR invoices, AP bills, GL journal entries, inventory issues/receipts)
- PM-specific transactions are entered on the Project Transactions (PM304000) form
- Allocations run and create derived transactions

Each PMTran maps to a specific Project + Task + Account Group + Cost Code + Inventory Item combination and carries amounts in three currency layers.

#### PM Register (PMRegister)
A batch of project transactions, analogous to a GL Batch. PMRegister records group PMTran records by source module.

#### Commitment (PMCommitment)
Represents a purchase commitment against the project budget, typically created from PO or subcontract lines. Commitments track original, revised, received, and invoiced quantities and amounts. They are linked to the project budget through the same key dimensions (Project + Task + Account Group + Cost Code + Inventory Item).

#### Change Order (PMChangeOrder)
A formal document that modifies the project budget (both cost and revenue sides) and/or commitments. Change orders contain:
- **Budget lines** (PMChangeOrderBudget) — adjustments to project budget
- **Commitment lines** (PMChangeOrderLine) — adjustments to PO/subcontract commitments

When released, change orders update the `ChangeOrderQty` / `CuryChangeOrderAmount` fields on PMBudget and modify commitment amounts on PMCommitment.

#### Change Request (PMChangeRequest)
A preliminary document that feeds into change orders. Change requests can be linked to a revenue change order (`ChangeOrderNbr`) and/or a cost change order (`CostChangeOrderNbr`). They feed the "Potential CO" (draft change order) fields on the budget.

#### Pro Forma Invoice (PMProforma)
An intermediate billing document created during project billing, before the final AR invoice. Pro forma invoices contain:
- **Progress lines** (PMProformaProgressLine) — for progress billing based on completion percentage
- **Time and Material lines** (PMProformaTransactLine) — for T&M billing based on actual transactions

When released, a pro forma creates an AR Invoice (ARRegister + ARInvoice). The linkage is via `ARInvoiceDocType` + `ARInvoiceRefNbr` on PMProforma.

#### Project History (PMHistory)
Aggregated actuals by financial period. Key: ProjectID + ProjectTaskID + AccountGroupID + InventoryID + CostCodeID + PeriodID + BranchID. Contains PTD (period-to-date) quantities and amounts.

#### Billing Record (PMBillingRecord)
Tracks billing events per project, linking to the generated pro forma invoice via `ProformaRefNbr`.

#### Subcontract
A purchase order of type `RS` (regularSubcontract). **Not a separate physical table** — it is a `[PXProjection]` over `POOrder`. Subcontracts create commitments against the project budget.

#### Project Quote (PMQuote / PMQuoteTask)
A pre-project proposal context. `PMQuote` is a projection over CRM quote/opportunity data, not a standalone SQL table. `PMQuoteTask` is a physical PM table that stores quote-specific task definitions by `QuoteID + TaskCD`. Quote data can seed project setup, but it is not approved project accounting truth until conversion creates or updates project structures.

#### Allocation, WIP, and Unbilled Summary Tables
`PMAllocation` and `PMAllocationDetail` define allocation policy and steps. Allocation execution can create derived `PMTran` records or mark/transform project transactions depending on rule settings.

`PMWipAdjustment` and `PMWipAdjustmentLine` store WIP overbilling/underbilling review and adjustment documents. `PMUnbilledDailySummary` stores a compact daily summary by Project + Task + Account Group + Date. These tables are derived control/accounting layers; do not treat them as original source activity.

#### Progress Worksheet
`PMProgressWorksheet` and `PMProgressWorksheetLine` capture construction progress quantities by project budget dimensions. They support progress billing and Daily Field Report links but are separate from pro forma/AR invoice storage.

#### Project Files / Project Entity Links
`PMProjectEntity` links a project to related documents/entities through `LinkedDocumentNoteID` and `LinkedEntityNoteID`. It is a document/evidence relationship table, not a financial transaction table.

#### Compliance Document
`ComplianceDocument` is the main CN physical table for compliance/lien-waiver/payment-control artifacts. It can reference project, tasks, cost code, customer, vendor, secondary vendor, subcontract, change order, AP bill/payment, AR payment, and other source objects.

#### Joint Payee / Joint Payment
`JointPayee` and `JointPayeePayment` store joint-check payment splits tied to AP invoice lines and AP payments. These tables control payment allocation; AP remains the owner of payable documents and CA/AP own settlement.

#### PJ Documents
`ProjectIssue`, `RequestForInformation`, `DailyFieldReport`, `DrawingLog`, `PhotoLog`, and `PJSubmittal` are physical PJ tables anchored by `ProjectId` and often `ProjectTaskId`. They store field/document coordination evidence, not budget, actual, AR/AP, or GL truth. Daily Field Report relation tables link field reports to issues, change requests/orders, progress worksheets, photos, receipts, labor/equipment, subcontractor activity, and notes.

#### Work Codes and Labor Classifications
`PMWorkCode`, `PMUnion`, and related source tables model payroll-adjacent labor classifications. They can influence labor rules and reporting but do not replace Project Task, Account Group, Cost Code, or Labor Item as project accounting dimensions.

### How Entities Relate Conceptually

```
PMProject (master)
  -> PMTask (children - one project has many tasks)
     -> PMBudget (budget lines per task+account group+cost code+inventory)
        -> tracks original, revised, actual, committed, invoiced, change order amounts
        -> links to PMHistory for period-by-period actuals
     -> PMTran (transactions affecting this task)

  -> PMCommitment (commitments from PO/subcontract lines)
     -> linked to POLine/POOrder - created/updated when PO is released

  -> PMChangeOrder
     -> PMChangeOrderBudget (budget adjustments)
     -> PMChangeOrderLine (commitment adjustments)

  -> PMChangeRequest (preliminary - feeds into change orders)

  -> PMProforma
     -> PMProformaLine (progress + T&M lines)
     -> on release creates ARRegister + ARInvoice

  -> PMBillingRecord (billing history)

  -> PMAllocation / PMAllocationDetail (allocation policy)
     -> execution may create or update derived PMTran behavior

  -> PMWipAdjustment
     -> PMWipAdjustmentLine (WIP review/adjustment)

  -> PMProgressWorksheet
     -> PMProgressWorksheetLine (progress capture)

  -> PMProjectEntity (project file/entity evidence links via NoteID)

  -> ComplianceDocument / JointPayee (CN payment/compliance controls)

  -> PJ documents (RFI, issue, daily field report, drawing, photo, submittal)
```

### Which Documents Create PM Transactions?

| Source Document | Module | Creates PMTran? | Creates GL? | Updates PMBudget? |
|---|---|---|---|---|
| AP Bill (APInvoice) release | AP | Yes (cost side) | Yes | Yes (actuals) |
| AR Invoice release | AR | Yes (revenue side) | Yes | Yes (actuals) |
| GL Journal Entry release | GL | Yes (if project referenced) | Yes | Yes (actuals) |
| Inventory Issue/Receipt | IN | Yes (if project referenced) | Yes | Yes (actuals) |
| SO Shipment ? AR Invoice | SO/AR | Yes (via AR release) | Yes | Yes (actuals) |
| Expense Claim release | EP | Yes | Yes | Yes (actuals) |
| PM Transaction (manual) | PM | Yes (on release) | Optional | Yes (actuals) |
| PO Order/Subcontract open | PO | No | No | Yes (commitments on PMBudget) |
| PO Receipt | PO | Yes (indirect via AP/IN) | Yes | Yes (commitment received qty) |
| Change Order release | PM | No PMTran | No | Yes (CO amounts on PMBudget; commitment amounts on PMCommitment) |
| Pro Forma release | PM | No PMTran directly | Via AR Invoice | Updates invoice amounts on PMBudget |

### How Commitments Become Costs

```
1. PO Order / Subcontract created with project lines
   ? PMCommitment records created (Qty, Amount, OrigQty, OrigAmount)
   ? PMBudget.CommittedQty / CommittedAmount updated

2. PO Receipt against the PO
   ? PMCommitment.ReceivedQty updated
   ? PMBudget.CommittedReceivedQty updated

3. AP Bill linked to PO Receipt released
   ? PMTran created (cost transaction)
   ? PMBudget.ActualQty / CuryActualAmount updated
   ? PMCommitment.InvoicedQty / InvoicedAmount updated
   ? PMBudget.CommittedInvoicedQty / CuryCommittedInvoicedAmount updated
   ? PMBudget.CommittedOpenQty / CuryCommittedOpenAmount recalculated
   ? GL Batch + GLTran created
```

### How Billing Works

```
1. Run billing on project (PM Billing process)
   ? Creates PMProforma with PMProformaLine records
   ? Updates PMBudget.CuryInvoicedAmount (draft invoice amount)
   ? Updates PMBudget.QtyToInvoice / CuryAmountToInvoice (pending)

2. Review and approve pro forma
   ? Status changes from Hold ? Open ? Approved

3. Release pro forma
   ? Creates ARRegister + ARInvoice (AR document)
   ? PMProforma.ARInvoiceDocType and ARInvoiceRefNbr populated
   ? PMBudget actuals updated when AR invoice is released
   ? PMTran records created (revenue side) when AR invoice is released
```

### How Retainage Behaves

Retainage in project billing is tracked through:
- PMProformaLine retainage fields (RetainagePct, CuryRetainage)
- ARTran retainage fields on the generated AR invoice
- ARRegister retainage account/sub fields
- The retainage amount is withheld from the billed amount until separately released

### Balance Accumulation

PMBudget serves as the **central balance accumulator**. Its key balance equation for cost budget:

```
Variance = RevisedBudgeted - (Actual + CommittedOpen)

Where:
  RevisedBudgeted = OriginalBudgeted + ChangeOrderAmount
  CommittedOpen = CommittedRevised - CommittedInvoiced
  CommittedRevised = CommittedOrig + CommittedCOAmount
```

For revenue budget:
```
CompletedPct drives billing amounts for progress billing
ActualAmount = total of released AR invoice amounts posted to this budget key
InvoicedAmount = total of unreleased (draft) AR invoice amounts
```

---

## 6. Business Concept ? Database Mapping Matrix

| Business Concept | Primary Table(s) | Supporting Table(s) | Business Key(s) | Technical Key(s) | Critical Join Path(s) | Common Pitfalls | Verification Starting Point |
|---|---|---|---|---|---|---|---|
| Project | Contract + PMProject | PMTask, Customer, PMAccountGroup | ContractCD | ContractID | `Contract JOIN PMProject ON same ContractID` (same row, extension table) | PMProject extends Contract; both share ContractID PK | `SELECT * FROM Contract c JOIN PMProject p ON c.CompanyID=p.CompanyID AND c.ContractID=p.ContractID` |
| Project Task | PMTask | PMProject, PMBudget | ProjectID + TaskCD | ProjectID + TaskID | `PMTask.ProjectID = PMProject.ContractID` | TaskID is identity but ProjectID is also part of PK | `SELECT * FROM PMTask WHERE ProjectID = @ProjectID` |
| Cost Code | PMCostCode | PMBudget, PMTran | CostCodeCD | CostCodeID | `PMBudget.CostCodeID = PMCostCode.CostCodeID` | Default cost code (ID=0) used when feature disabled | Check CostCodeID = 0 for "no cost code" |
| Account Group | PMAccountGroup | PMBudget, PMTran, Account | GroupCD | GroupID | `PMBudget.AccountGroupID = PMAccountGroup.GroupID` | Type field determines cost vs revenue budget | Filter by Type: 'E'=Expense(cost), 'I'=Income(revenue) |
| Cost Budget Line | PMBudget (Type='E') | PMTask, PMAccountGroup, PMCostCode | ProjectID+TaskID+AcctGrpID+CostCodeID+InvID | Same (5-part PK) | All 5 key fields must match | Type='E' for cost; missing any key part = wrong match | `SELECT * FROM PMBudget WHERE ProjectID=@ProjID AND Type IN ('E','A','L','O')` |
| Revenue Budget Line | PMBudget (Type='I') | PMTask, PMAccountGroup | ProjectID+TaskID+AcctGrpID+CostCodeID+InvID | Same (5-part PK) | Same as cost budget | Type='I' for revenue | `SELECT * FROM PMBudget WHERE ProjectID=@ProjID AND Type='I'` |
| Project Transaction | PMTran | PMRegister, PMProject, PMTask | TranID | TranID (bigint identity) | `PMTran.RefNbr=PMRegister.RefNbr AND PMTran.TranType=PMRegister.Module` | Multiple currency layers; check Released flag | `SELECT * FROM PMTran WHERE ProjectID=@ProjID AND Released=1` |
| PM Batch | PMRegister | PMTran | Module + RefNbr | Module + RefNbr | `PMRegister ? PMTran via Module+RefNbr` | Module field = source module code | `SELECT * FROM PMRegister WHERE Module='PM'` |
| Commitment | PMCommitment | POOrder, POLine, PMBudget | CommitmentID (GUID) | CommitmentID | Links to POLine via GUID (POLine.CommitmentID) | GUID-based PK; amounts in base currency | `SELECT * FROM PMCommitment WHERE ProjectID=@ProjID` |
| Change Order | PMChangeOrder | PMChangeOrderBudget, PMChangeOrderLine | RefNbr | RefNbr | `PMChangeOrderBudget.RefNbr = PMChangeOrder.RefNbr` | Status field; check Released/Closed | `SELECT * FROM PMChangeOrder WHERE ProjectID=@ProjID` |
| CO Budget Line | PMChangeOrderBudget | PMChangeOrder, PMBudget | RefNbr + LineNbr | RefNbr + LineNbr | Maps to PMBudget via ProjectID+TaskID+AcctGrpID+CostCodeID+InvID | Two derived types: Revenue and Cost budget | Match budget key dimensions |
| CO Commitment Line | PMChangeOrderLine | PMChangeOrder, PMCommitment, POOrder | RefNbr + LineNbr | RefNbr + LineNbr | Links to PO via POOrderType+POOrderNbr | Adjusts commitment amounts | Check POOrderType and POOrderNbr fields |
| Change Request | PMChangeRequest | PMChangeOrder | RefNbr | RefNbr | `PMChangeRequest.ChangeOrderNbr ? PMChangeOrder.RefNbr` | Two CO links: revenue CO and cost CO | Check ChangeOrderNbr and CostChangeOrderNbr |
| Pro Forma Invoice | PMProforma | PMProformaLine, ARInvoice, PMProject | RefNbr + RevisionID | RefNbr + RevisionID | `PMProforma.ARInvoiceDocType+ARInvoiceRefNbr ? ARRegister` | RevisionID is part of PK; check Corrected flag | `SELECT * FROM PMProforma WHERE ProjectID=@ProjID` |
| Pro Forma Line | PMProformaLine | PMProforma, PMBudget, PMTran | RefNbr + RevisionID + LineNbr | Same | `PMProformaLine.RefNbr+RevisionID = PMProforma.RefNbr+RevisionID` | Two sub-types: Progress and Transact | Check Type field on line |
| Project History | PMHistory | PMBudget, PMProject | ProjID+TaskID+AcctGrpID+InvID+CostCodeID+PeriodID+BranchID | Same (7-part PK) | Same key dimensions as PMBudget + PeriodID + BranchID | Period-to-date amounts; must sum for YTD | `SELECT * FROM PMHistory WHERE ProjectID=@ProjID` |
| Billing Record | PMBillingRecord | PMProforma, PMProject | ProjectID + RecordID + BillingTag | Same | `PMBillingRecord.ProformaRefNbr ? PMProforma.RefNbr` | BillingTag segments billing by task/location | Check ProformaRefNbr for linking |
| Project Quote | PMQuote projection + PMQuoteTask | CRQuote, CROpportunityRevision, CROpportunity | QuoteNbr / QuoteID | QuoteID + TaskCD for quote tasks | `PMQuoteTask.QuoteID -> CRQuote.QuoteID` | No standalone PMQuote SQL table; quote is proposal context | Check CRM quote/opportunity tables plus PMQuoteTask |
| Allocation Rule | PMAllocation + PMAllocationDetail | PMTran, PMRegister, PMTask, PMAccountGroup | AllocationID | AllocationID + StepID | Contract/PMTask hold default AllocationID; detail steps drive derived PMTran behavior | Rule execution is graph logic, not fully visible from tables | Start with PMAllocationDetail, then inspect generated PMTran lineage |
| WIP Adjustment | PMWipAdjustment + PMWipAdjustmentLine | PMTran, GL Batch, PMBudget | RefNbr | RefNbr + LineNbr | Header RefNbr -> lines; released adjustment may link BatchNbr | WIP is timing/control, not original actual source | Check PMWipAdjustment Released/BatchNbr and line project keys |
| Unbilled Summary | PMUnbilledDailySummary | PMTran, PMBillingRecord | ProjectID+TaskID+AccountGroupID+Date | Same | Same project/task/account-group dimensions | Summary table; not source of billable transactions | Use as aggregate clue, then trace PMTran/billing records |
| Progress Worksheet | PMProgressWorksheet + PMProgressWorksheetLine | PMBudget, PMProformaLine, DailyFieldReportProgressWorksheet | RefNbr | RefNbr + LineNbr | Lines carry ProjectID + TaskID + AccountGroupID + InventoryID + CostCodeID | Progress capture is not AR invoice storage | Check worksheet status/released and matching budget keys |
| Project Files / Linked Evidence | PMProjectEntity | Note, UploadFile, entity tables by NoteID | ProjectID + linked NoteIDs | ProjectID + LinkedDocumentNoteID + LinkedEntityNoteID | `PMProjectEntity.ProjectID -> Contract.ContractID`; NoteID joins to owning documents/files | Evidence links are not business transactions | Query PMProjectEntity by ProjectID and NoteID anchors |
| Compliance Document | ComplianceDocument | ComplianceDocumentBill, ComplianceDocumentReference, AP/AR/PO/PM source docs | ComplianceDocumentID | ComplianceDocumentID | ProjectID/VendorID/CustomerID/Subcontract/BillID/InvoiceID/Payment refs vary by source | Many nullable anchors; use source type and exact reference fields | Start by ProjectID/VendorID, then follow Bill/Invoice/Payment/Subcontract refs |
| Joint Payee | JointPayee + JointPayeePayment | APInvoice/APTran, APPayment/APAdjust | JointPayeeID | JointPayeeID / JointPayeePaymentId | JointPayee APDocType+APRefNbr+APLineNbr -> APTran; payments by PaymentDocType+PaymentRefNbr | Joint checks split AP payment; they are not AP document ownership | Start with AP bill line, then JointPayee and JointPayeePayment |
| PJ Field Document | ProjectIssue / RequestForInformation / DailyFieldReport / DrawingLog / PhotoLog / PJSubmittal | relation tables, PMProjectEntity, Note attachments | Document CD or SubmittalID | identity or composite key depending table | Most PJ headers join by ProjectId + optional ProjectTaskId | PJ documents are evidence/coordination, not financial state | Query by ProjectId/ProjectTaskId and status/NoteID |
| Work Code / Labor Classification | PMWorkCode, PMUnion, PMWorkCode*Source tables | PMTimeActivity, PR tables, PMTask, inventory/labor items | WorkCodeID / UnionID | WorkCodeID / UnionID | Work code source tables connect work code to project/task, cost code ranges, or labor items | Payroll-adjacent classification, not budget key replacement | Start with WorkCodeID, then source tables and labor transactions |
| Subcontract | POOrder (Type='RS') | POLine, PMCommitment, Vendor | OrderType + OrderNbr | OrderType + OrderNbr | `POOrder.OrderType='RS'` — Subcontract DAC is a projection | **No physical Subcontract table** — query POOrder | `SELECT * FROM POOrder WHERE OrderType='RS'` |
| AR Invoice (from project) | ARRegister + ARInvoice | PMProforma, PMTran, ARTran | DocType + RefNbr | DocType + RefNbr | `ARRegister JOIN ARInvoice ON same PK; PMProforma.ARInvoiceRefNbr` | Must join base+extension; check ProjectID on ARRegister | `SELECT * FROM ARRegister WHERE ProjectID=@ProjID` |
| AP Bill (for project) | APRegister + APInvoice | APTran, PMTran, POOrder | DocType + RefNbr | DocType + RefNbr | `APRegister JOIN APInvoice ON same PK` | Check ProjectID on APTran lines, not just header | `SELECT * FROM APTran WHERE ProjectID=@ProjID` |
| GL Journal Entry | Batch + GLTran | PMTran | Module + BatchNbr + LineNbr | Same | `GLTran.ProjectID ? PMProject.ContractID` | PMTran.BatchNbr links to Batch.BatchNbr | Check GLTran.ProjectID and TaskID |

---

## 7. Module-by-Module Database Model

### PM — Project Management

#### Table: Contract (Base for PMProject)

- **DAC:** `PX.Objects.CT.Contract`
- **Persistence:** `physical_table`
- **Business Description:** Base table shared between Contracts and Projects modules. PMProject inherits from Contract and extends it with `[PXTable]`. The Contract table holds core fields like ContractID, ContractCD, Status, CustomerID, StartDate, ExpireDate, BillingID, AllocationID, and module visibility flags.

| Column | Type | PK | Description |
|---|---|---|---|
| ContractID | int (identity) | Yes | Surrogate key |
| BaseType | string(1) | Yes | 'P'=Project, 'C'=Contract |
| ContractCD | string | UK | Segmented key — human-readable project code |
| Description | string(255) | | Project description |
| Status | string(1) | | See ProjectStatus |
| CustomerID | int | FK?Customer | Customer for external projects; NULL for internal |
| LocationID | int | FK?Location | Customer location |
| BillingID | string | FK?PMBilling | Default billing rule |
| AllocationID | string | FK?PMAllocation | Default allocation rule |
| TermsID | string(10) | FK?Terms | Credit terms |
| StartDate | datetime | | Project start date |
| ExpireDate | datetime | | Project end date |
| Hold | bool | | On hold flag |
| IsActive | bool | | Active flag |
| IsCompleted | bool | | Completed flag |
| IsCancelled | bool | | Cancelled flag |
| TemplateID | int | FK?PMProject | Template project |
| DefaultBranchID | int | FK?Branch | Default branch |
| NoteID | guid | | Note/attachment link |

**ProjectStatus Values (from source code):**

| Constant | Value | Display |
|---|---|---|
| Planned | 'D' (Draft) | In Planning |
| Active | 'A' | Active |
| Completed | 'C' | Completed |
| Suspended | 'E' (Expired) | Suspended |
| Cancelled | 'X' | Canceled |
| PendingApproval | 'I' (InApproval) | Pending Approval |
| OnHold | 'H' | On Hold |
| Rejected | 'J' | Rejected |
| Closed | 'L' | Closed |

#### Table: PMProject (Extension of Contract)

- **DAC:** `PX.Objects.PM.PMProject`
- **Persistence:** `extension_table` (extends Contract via `[PXTable]`)
- **PK:** Same as Contract: `ContractID`
- **Business Description:** PM-specific extension fields for projects.

| Column | Type | Description |
|---|---|---|
| BudgetLevel | string(1) | Revenue budget detail level: T=Task, I=Task+Item, C=Task+CostCode, D=Task+Item+CostCode |
| CostBudgetLevel | string(1) | Cost budget detail level (same values) |
| BudgetFinalized | bool | Budget is locked |
| BaseCuryID | string(5) | Base currency of the project |
| CuryID | string(5) | Budget/project currency |
| BillingCuryID | string(5) | Billing currency (for invoices) |
| RateTypeID | string(6) | Currency rate type |
| CuryInfoID | long | FK?CurrencyInfo |
| BillAddressID | int | FK?PMAddress (billing address snapshot) |
| BillContactID | int | FK?PMContact (billing contact snapshot) |
| SiteAddressID | int | FK?PMAddress (site address) |
| AccountingMode | string(1) | P=Track by Project Qty+Cost, V=Track Qty, L=Track by Location |
| AutoAllocate | bool | Run allocation on release |
| VisibleInGL/AR/AP/SO/PO/IN/CA/TA/EA/CR | bool | Module visibility flags |
| NonProject | bool | True for the single "non-project" placeholder |
| RateTableID | string | FK?PMRateTable |
| ApproverID | int | FK?BAccount (time activity approver) |
| OwnerID | int | Project manager |
| CalculateProjectedCostByQuantity | bool | Projected cost calculation method |
| RevenuePercentageCalculationRule | string(15) | FK?PMRevenuePercentageCalculationRule |
| ChangeOrderWorkflow | bool | Change order feature enabled for this project |
| CertifiedJob | bool | Certified job flag (construction) |
| LastProformaNumber | string | Last generated proforma number |

**SQL Join Hint:**
```sql
-- Complete project data requires joining Contract + PMProject
SELECT c.ContractCD, c.Description, c.Status, c.CustomerID,
       p.BudgetLevel, p.CostBudgetLevel, p.CuryID, p.BillingCuryID
FROM Contract c
JOIN PMProject p ON c.CompanyID = p.CompanyID AND c.ContractID = p.ContractID
WHERE c.CompanyID = @CompanyID
  AND c.BaseType = 'P'  -- Projects only
  AND c.NonProject = 0  -- Exclude non-project
```

---

#### Table: PMTask

- **DAC:** `PX.Objects.PM.PMTask`
- **Persistence:** `physical_table`
- **PXCacheName:** `Project Task`
- **PK:** `ProjectID + TaskID` (TaskID is identity)
- **UK:** `ProjectID + TaskCD`
- **Parent:** PMProject (via `[PXParent]` on ProjectID)

| Column | Type | PK | FK | Description |
|---|---|---|---|---|
| ProjectID | int | Yes | FK?PMProject.ContractID | Parent project |
| TaskID | int (identity) | Yes | | Surrogate key |
| TaskCD | string | UK | | Segmented key |
| Description | string(250) | | | Task description |
| CustomerID | int | | FK?Customer | Copied from project |
| LocationID | int | | FK?Location | Customer location |
| BillingID | string | | FK?PMBilling | Billing rule (defaults from project) |
| AllocationID | string | | FK?PMAllocation | Allocation rule |
| RateTableID | string | | FK?PMRateTable | Rate table |
| BillingOption | string(1) | | | B=OnBilling, T=OnTaskCompletion, P=OnProjectCompletion |
| CompletedPctMethod | string(1) | | | Completion calculation method |
| Status | string(1) | | | Task status |
| Type | string(1) | | | Task type (revenue/cost/combined) |
| PlannedStartDate | datetime | | | |
| PlannedEndDate | datetime | | | |
| StartDate | datetime | | | Actual start |
| EndDate | datetime | | | Actual end |
| IsDefault | bool | | | Default task for the project |
| IsActive | bool | | | Active flag |
| IsCompleted | bool | | | Completed flag |
| CompletedPercent | decimal | | | Completion percentage |
| BillSeparately | bool | | | Bill on separate invoice |
| RevenuePercentageCalculationRule | string(15) | | FK?PMRevenuePercentageCalculationRule | |
| NoteID | guid | | | Note link |

**ProjectTaskStatus Values:**

| Constant | Value | Display |
|---|---|---|
| Planned | 'D' | In Planning |
| Active | 'A' | Active |
| Canceled | 'C' | Canceled |
| Completed | 'F' | Completed |

---

#### Table: PMAccountGroup

- **DAC:** `PX.Objects.PM.PMAccountGroup`
- **Persistence:** `physical_table`
- **PK:** `GroupID` (identity)
- **UK:** `GroupCD`

| Column | Type | Description |
|---|---|---|
| GroupID | int (identity) | Surrogate key |
| GroupCD | string | Segmented key |
| Description | string(250) | |
| IsActive | bool | Active flag |
| IsExpense | bool | True = appears on cost budget tab |
| Type | string(1) | A=Asset, L=Liability, I=Income, E=Expense, O=Off-Balance |
| ReportGroup | string(1) | L=Labor, M=Material, S=Subcontract, E=Equipment, O=Other, R=Revenue |
| RevenueAccountGroupID | int | Default revenue account group for this expense group |
| AccountID | int | Default GL account |
| SortOrder | smallint | Display sort order |
| DefaultLineMarkupPct | decimal | Default markup % for change requests |
| CalculateProjectedCostByQuantity | bool | Override per account group |

**Support Note:** The `Type` field determines which budget tab the account group appears on. `E` (Expense) and `A` (Asset) go to Cost Budget; `I` (Income) goes to Revenue Budget. `O` (Off-Balance) tracks non-financial metrics.

---

#### Table: PMCostCode

- **DAC:** `PX.Objects.PM.PMCostCode`
- **Persistence:** `physical_table`
- **PK:** `CostCodeID` (identity)
- **UK:** `CostCodeCD`

| Column | Type | Description |
|---|---|---|
| CostCodeID | int (identity) | Surrogate key |
| CostCodeCD | string | Segmented key |
| Description | string(250) | |
| IsActive | bool | Active flag |

**Support Note:** When the Cost Codes feature is disabled, all records use `CostCodeID = 0` (the default cost code). When enabled, cost codes add granularity to the budget key.

---

#### Table: PMBudget

- **DAC:** `PX.Objects.PM.PMBudget`
- **Persistence:** `physical_table`
- **PXCacheName:** `PM Budget`
- **PK:** `ProjectID + ProjectTaskID + AccountGroupID + CostCodeID + InventoryID` (5-part composite)

This is the **central balance accumulator** for project accounting.

**Key Fields:**

| Column | Type | PK | Description |
|---|---|---|---|
| ProjectID | int | Yes | FK?PMProject.ContractID |
| ProjectTaskID | int | Yes | FK?PMTask.TaskID |
| AccountGroupID | int | Yes | FK?PMAccountGroup.GroupID |
| CostCodeID | int | Yes | FK?PMCostCode.CostCodeID |
| InventoryID | int | Yes | FK?InventoryItem.InventoryID (0=N/A) |
| Type | string(1) | | A/L/I/E/O — from account group type |
| Description | string | | Budget line description |
| UOM | string | | Unit of measure |

**Original Budget Fields:**

| Column | Currency | Description |
|---|---|---|
| Qty | | Original budgeted quantity |
| CuryUnitRate / Rate | Project / Base | Unit rate |
| CuryAmount / Amount | Project / Base | Original budgeted amount |

**Revised Budget Fields:**

| Column | Currency | Description |
|---|---|---|
| RevisedQty | | Revised budgeted quantity (original + CO) |
| CuryRevisedAmount / RevisedAmount | Project / Base | Revised budgeted amount |

**Actual Fields:**

| Column | Currency | Description |
|---|---|---|
| ActualQty | | Actual quantity (from released transactions) |
| CuryActualAmount / ActualAmount | Project / Base | Actual amount |

**Change Order Fields:**

| Column | Currency | Description |
|---|---|---|
| ChangeOrderQty | | Total qty from released COs |
| CuryChangeOrderAmount / ChangeOrderAmount | Project / Base | Total amount from released COs |
| DraftChangeOrderQty | | Total qty from open COs + change requests |
| CuryDraftChangeOrderAmount / DraftChangeOrderAmount | Project / Base | Potential CO amount |

**Commitment Fields:**

| Column | Currency | Description |
|---|---|---|
| CommittedQty / CuryCommittedAmount | | Revised committed (original + CO) |
| CommittedOrigQty / CuryCommittedOrigAmount | | Original committed |
| CommittedOpenQty / CuryCommittedOpenAmount | | Open committed (not yet invoiced via AP) |
| CommittedReceivedQty | | Received via PO receipt |
| CommittedInvoicedQty / CuryCommittedInvoicedAmount | | Invoiced via AP bill |

**Computed Fields (NOT persisted):**

| Column | Formula | Description |
|---|---|---|
| CommittedCOQty | CommittedQty - CommittedOrigQty | CO adjustment to commitments |
| CuryCommittedCOAmount | CuryCommittedAmount - CuryCommittedOrigAmount | |
| CuryActualPlusOpenCommittedAmount | CuryActualAmount + CuryCommittedOpenAmount | Total exposure |
| CuryVarianceAmount | CuryRevisedAmount - CuryActualPlusOpenCommittedAmount | Budget variance |
| Performance | (CuryActualAmount / CuryRevisedAmount) × 100 | Performance % |

**Billing Fields (Revenue budget):**

| Column | Description |
|---|---|
| InvoicedQty / CuryInvoicedAmount | Draft (unreleased) invoice amounts |
| QtyToInvoice / CuryAmountToInvoice | Pending invoice amount (next billing) |
| CompletedPct | Completion percentage |
| CuryUnitPrice / UnitPrice | Unit price for billing |
| LimitQty / LimitAmount | Billing limits enabled |
| MaxQty / CuryMaxAmount | Maximum billable |
| IsProduction | Auto-complete percentage flag |
| Mode | A=Auto, M=Manual — tracks completed pct source |
| ProgressBillingBase | Amount or Quantity-based progress |

---

#### Table: PMTran

- **DAC:** `PX.Objects.PM.PMTran`
- **Persistence:** `physical_table`
- **PK:** `TranID` (bigint identity)
- **Parent:** PMRegister (via `[PXParent]` on TranType + RefNbr)

| Column | Type | Description |
|---|---|---|
| TranID | bigint (identity) | Unique transaction identifier |
| TranType | string(2) | Source module code (PM, GL, AR, AP, IN, CA, etc.) |
| RefNbr | string(15) | PM Register reference number |
| BranchID | int | FK?Branch |
| Date | datetime | Transaction date |
| FinPeriodID | string | Financial period |
| TranPeriodID | string | Master financial period |
| ProjectID | int | FK?PMProject.ContractID |
| TaskID | int | FK?PMTask.TaskID |
| AccountGroupID | int | FK?PMAccountGroup.GroupID |
| CostCodeID | int | FK?PMCostCode.CostCodeID |
| InventoryID | int | FK?InventoryItem |
| AccountID | int | Debit GL account |
| SubID | int | Debit subaccount |
| OffsetAccountID | int | Credit GL account |
| OffsetAccountGroupID | int | Credit account group |
| BAccountID | int | FK?BAccount (customer or vendor) |
| ResourceID | int | FK?BAccount (employee) |
| LocationID | int | FK?Location |
| Description | string | Transaction description |
| UOM | string | Unit of measure |
| Qty | decimal | Quantity |
| BillableQty | decimal | Billable quantity |
| Billable | bool | Is billable |
| UseBillableQty | bool | Use billable qty in amount formula |

**Amount Fields (three currency layers):**

| Column | Currency Layer | Description |
|---|---|---|
| TranCuryUnitRate / UnitRate | Transaction / Base | Unit rate |
| TranCuryAmount / Amount | Transaction / Base | Transaction amount |
| ProjectCuryAmount | Project | Amount in project currency |
| TranCuryID | | Transaction currency code |
| BaseCuryInfoID | | CurrencyInfo for tran?base rate |
| ProjectCuryInfoID | | CurrencyInfo for tran?project rate |

**Status and Lifecycle Fields:**

| Column | Description |
|---|---|
| Released | Released flag |
| Allocated | Has been allocated |
| ExcludedFromAllocation | Excluded from allocation processing |
| Billed | Has been billed |
| ExcludedFromBilling | Excluded from billing |
| ExcludedFromBillingReason | Reason for billing exclusion |
| Reversed | Has been reversed |

**Source Document Lineage Fields:**

| Column | Description |
|---|---|
| BatchNbr | GL Batch number (links to Batch table) |
| OrigModule | Source module of the GL batch |
| OrigTranType | Source document type |
| OrigRefNbr | Source document reference number |
| OrigLineNbr | Source document line number |
| BillingID | Billing rule used |
| AllocationID | Allocation rule used |
| InvoicedQty / ProjectCuryInvoicedAmount / InvoicedAmount | Billed qty/amount |
| ProformaRefNbr | Pro forma reference |
| ProformaLineNbr | Pro forma line number |
| ARTranType / ARRefNbr | AR document type and number |

**Support Investigation Notes:**
- `OrigTranType` + `OrigRefNbr` + `OrigModule` trace back to the originating financial document.
- `BatchNbr` links to the GL Batch for GL-level verification.
- `Released = 1` means the transaction has been processed and affects balances.
- `Billed = 1` means the transaction has been included in a billing run.
- `Allocated = 1` means an allocation rule has processed this transaction.

---

#### Table: PMRegister

- **DAC:** `PX.Objects.PM.PMRegister`
- **Persistence:** `physical_table`
- **PK:** `Module + RefNbr`

| Column | Type | Description |
|---|---|---|
| Module | string(2) | Source module: PM, GL, AR, AP, IN, CA, DR, PR |
| RefNbr | string(15) | Reference number (auto-numbered) |
| Date | datetime | Transaction date |
| Description | string(255) | Batch description |
| Status | string(1) | H=Hold, B=Balanced, R=Released |
| Released | bool | Released flag |
| OrigDocType | string(3) | Original document type |
| OrigDocNbr | string(15) | Original document number |
| QtyTotal | decimal | Total quantity (sum of PMTran.Qty) |
| BillableQtyTotal | decimal | Total billable quantity |
| AmtTotal | decimal | Total amount (sum of PMTran.Amount) |

---

#### Table: PMCommitment

- **DAC:** `PX.Objects.PM.PMCommitment`
- **Persistence:** `physical_table`
- **PK:** `CommitmentID` (GUID)

| Column | Type | Description |
|---|---|---|
| CommitmentID | guid | Unique identifier |
| Type | string(1) | I=Internal (PO/Subcontract), E=External |
| Status | string(1) | O=Open, C=Closed |
| BranchID | int | FK?Branch |
| ProjectID | int | FK?PMProject.ContractID |
| ProjectTaskID | int | FK?PMTask.TaskID |
| AccountGroupID | int | FK?PMAccountGroup.GroupID |
| CostCodeID | int | FK?PMCostCode.CostCodeID |
| InventoryID | int | FK?InventoryItem |
| UOM | string | Unit of measure |
| ExtRefNbr | string(15) | External reference number |

**Amount Fields:**

| Column | Currency | Description |
|---|---|---|
| OrigQty / OrigAmount | Base | Original committed (before CO) |
| Qty / Amount | Base | Revised committed (after CO) |
| ReceivedQty | | Received via PO receipt |
| InvoicedQty / InvoicedAmount | Base | Invoiced via AP bill |

**Computed Fields (NOT persisted):**

| Column | Formula | Description |
|---|---|---|
| CommittedCOQty | Qty - OrigQty | CO adjustment quantity |
| CommittedCOAmount | Amount - OrigAmount | CO adjustment amount |
| CommittedVarianceQty | Qty - InvoicedQty | Remaining open quantity |
| CommittedVarianceAmount | Amount - InvoicedAmount | Remaining open amount |
| OpenQty | Qty - InvoicedQty | Open committed quantity |
| OpenAmount | Amount - InvoicedAmount | Open committed amount |

**Linkage to PO:**
PMCommitment.CommitmentID = POLine.CommitmentID (the PO line stores the GUID linking to this commitment record).

---

#### Table: PMChangeOrder

- **DAC:** `PX.Objects.PM.PMChangeOrder`
- **Persistence:** `physical_table`
- **PK:** `RefNbr`

| Column | Type | Description |
|---|---|---|
| RefNbr | string(15) | Unique reference number |
| ProjectNbr | string(15) | Revenue change order number |
| ClassID | string | FK?PMChangeOrderClass |
| Description | string | |
| Status | string(1) | H=OnHold, A=PendingApproval, O=Open, C=Closed, R=Rejected |
| Hold | bool | On hold |
| Approved | bool | Approved flag |
| Rejected | bool | Rejected flag |
| Canceled | bool | Canceled flag |
| ProjectID | int | FK?PMProject.ContractID |
| CustomerID | int | FK?Customer (derived from project) |
| Date | datetime | Change date |
| CompletionDate | datetime | Approval date |
| NoteID | guid | Note link |

**ChangeOrderStatus Values:**

| Value | Display |
|---|---|
| 'H' | On Hold |
| 'A' | Pending Approval |
| 'O' | Open |
| 'C' | Closed |
| 'R' | Rejected |

---

#### Table: PMChangeOrderBudget

- **DAC:** `PX.Objects.PM.PMChangeOrderBudget`
- **Persistence:** `physical_table`
- **PK:** `RefNbr + LineNbr`
- **Parent:** PMChangeOrder (via `[PXParent]`)

Budget adjustment line on a change order. Maps to PMBudget via the same key dimensions (ProjectID + TaskID + AccountGroupID + CostCodeID + InventoryID).

---

#### Table: PMChangeOrderLine

- **DAC:** `PX.Objects.PM.PMChangeOrderLine`
- **Persistence:** `physical_table`
- **PK:** `RefNbr + LineNbr`
- **Parent:** PMChangeOrder (via `[PXParent]`)

Commitment adjustment line on a change order. Links to PO/Subcontract via POOrderType + POOrderNbr.

---

#### Table: PMChangeRequest

- **DAC:** `PX.Objects.PM.PMChangeRequest`
- **Persistence:** `physical_table`
- **PK:** `RefNbr`

| Column | Type | Description |
|---|---|---|
| RefNbr | string(15) | Unique reference number |
| ChangeOrderNbr | string(15) | FK?PMChangeOrder.RefNbr (revenue CO) |
| CostChangeOrderNbr | string(15) | FK?PMChangeOrder.RefNbr (cost CO) |
| ProjectID | int | FK?PMProject.ContractID |
| Status | string(1) | H=OnHold, A=PendingApproval, O=Open, C=Closed |
| Description | string | |

---

#### Table: PMProforma

- **DAC:** `PX.Objects.PM.PMProforma`
- **Persistence:** `physical_table`
- **PK:** `RefNbr + RevisionID`

| Column | Type | Description |
|---|---|---|
| RefNbr | string(15) | Reference number |
| RevisionID | int | Revision number (starts at 1) |
| ProjectNbr | string(15) | Application number (construction) |
| Description | string(255) | |
| Status | string(1) | H=OnHold, A=PendingApproval, O=Open, C=Closed, R=Rejected |
| Hold | bool | On hold |
| Approved | bool | |
| Rejected | bool | |
| Corrected | bool | Has been corrected/replaced |
| BranchID | int | FK?Branch |
| ProjectID | int | FK?PMProject.ContractID |
| CustomerID | int | FK?Customer |
| LocationID | int | FK?Location |
| CuryID | string(5) | Invoice currency |
| CuryInfoID | long | FK?CurrencyInfo |
| InvoiceDate | datetime | Invoice date |
| TaxZoneID | string(10) | FK?TaxZone |
| ARInvoiceDocType | string(3) | AR document type (created on release) |
| ARInvoiceRefNbr | string(15) | AR document ref (created on release) |
| ReversedARInvoiceDocType | string(3) | Reversing AR doc type |
| ReversedARInvoiceRefNbr | string(15) | Reversing AR doc ref |
| NoteID | guid | Note link |

**ProformaStatus Values:**

| Value | Display |
|---|---|
| 'H' | On Hold |
| 'A' | Pending Approval |
| 'O' | Open |
| 'C' | Closed |
| 'R' | Rejected |

---

#### Table: PMProformaLine

- **DAC:** `PX.Objects.PM.PMProformaLine`
- **Persistence:** `physical_table`
- **PK:** `RefNbr + RevisionID + LineNbr`
- **Parent:** PMProforma (via `[PXParent]`)

Base class for progress lines (PMProformaProgressLine) and transactional lines (PMProformaTransactLine). Contains project/task/account group/cost code/inventory references and amount fields.

---

#### Table: PMHistory

- **DAC:** `PX.Objects.PM.PMHistory`
- **Persistence:** `physical_table`
- **PK:** `ProjectID + ProjectTaskID + AccountGroupID + InventoryID + CostCodeID + PeriodID + BranchID` (7-part)

| Column | Type | Description |
|---|---|---|
| ProjectID | int | FK?PMProject |
| ProjectTaskID | int | FK?PMTask |
| AccountGroupID | int | FK?PMAccountGroup |
| InventoryID | int | FK?InventoryItem |
| CostCodeID | int | FK?PMCostCode |
| PeriodID | string | Master financial period |
| BranchID | int | FK?Branch |
| FinPTDQty | decimal | Financial PTD quantity |
| TranPTDQty | decimal | Transaction PTD quantity |
| FinPTDCuryAmount | decimal | Financial PTD amount (project currency) |
| FinPTDAmount | decimal | Financial PTD amount (base currency) |
| TranPTDCuryAmount | decimal | Transaction PTD amount (project currency) |
| TranPTDAmount | decimal | Transaction PTD amount (base currency) |

---

#### Table: PMBillingRecord

- **DAC:** `PX.Objects.PM.PMBillingRecord`
- **Persistence:** `physical_table`
- **PK:** `ProjectID + RecordID + BillingTag`

| Column | Type | Description |
|---|---|---|
| ProjectID | int | FK?PMProject |
| RecordID | int | Sequence number |
| BillingTag | string(30) | Billing segregation tag (T=TaskID, L=LocationID, P=Default) |
| Date | datetime | Billing date |
| ProformaRefNbr | string(15) | FK?PMProforma.RefNbr |
| ARDocType | string(3) | AR document type |
| ARRefNbr | string(15) | AR document reference |
| SortOrder | int | |

---

### Additional PM Table Families

These PM tables are important for connecting the business model to storage, but they are usually used as policy, derived-control, evidence, or proposal layers rather than as the central actual/budget tables.

| Table / Family | Persistence | Primary Key | Main Join Anchors | Diagnostic Use |
|---|---|---|---|---|
| `PMQuote` | projection | QuoteNbr in projection | CRM `CRQuote.QuoteID`, `CROpportunityRevision`, `CROpportunity` | Project quote/proposal context; do not query as a SQL table |
| `PMQuoteTask` | physical_table | `CompanyID + QuoteID + TaskCD` | `QuoteID -> CRQuote.QuoteID` | Tasks proposed before project conversion |
| `PMAllocation` | physical_table | `CompanyID + AllocationID` | Contract/PMTask `AllocationID` | Allocation rule header |
| `PMAllocationDetail` | physical_table | `CompanyID + AllocationID + StepID` | account group, task, project, cost code, rate type fields | Allocation step policy and formulas |
| `PMAllocationSourceTran`, `PMAllocationAuditTran` | physical_table | allocation-specific keys | PMTran lineage | Allocation execution/audit trace |
| `PMWipAdjustment` | physical_table | `CompanyID + RefNbr` | `BatchNbr`, owner/workgroup, status flags | WIP overbilling/underbilling document header |
| `PMWipAdjustmentLine` | physical_table | `CompanyID + RefNbr + LineNbr` | project budget dimensions | WIP adjustment detail by project key |
| `PMUnbilledDailySummary` | physical_table | `CompanyID + ProjectID + TaskID + AccountGroupID + Date` | PMTran/billing dimensions | Aggregate clue for unbilled daily state; not source activity |
| `PMProgressWorksheet` | physical_table | `CompanyID + RefNbr` | `ProjectID`, status flags | Progress capture header |
| `PMProgressWorksheetLine` | physical_table | `CompanyID + RefNbr + LineNbr` | ProjectID, TaskID, AccountGroupID, InventoryID, CostCodeID | Progress quantities by budget dimensions |
| `PMProjectEntity` | physical_table | `CompanyID + ProjectID + LinkedDocumentNoteID + LinkedEntityNoteID` | NoteID of linked documents/entities | Project files and linked evidence |
| `PMWorkCode`, `PMUnion`, `PMWorkCode*Source` | physical_table | code-specific keys | project/task, cost-code range, labor item, PR references | Payroll-adjacent labor classification |

**Key rule:** If a table in this group looks like a source of financial truth, verify whether it is actually policy (`PMAllocation*`), proposal (`PMQuote*`), derived accounting control (`PMWip*`, `PMUnbilledDailySummary`), progress capture (`PMProgressWorksheet*`), or evidence (`PMProjectEntity`) before using it as proof.

---

### CN - Construction Physical Tables

CN tables extend project accounting with construction payment and compliance controls. They usually point back to PM/PO/AP/AR entities rather than replacing them.

| Table / Family | Primary Key | Main Join Anchors | Diagnostic Use | Common Pitfall |
|---|---|---|---|---|
| `ComplianceDocument` | `CompanyID + ComplianceDocumentID` | `ProjectID`, `CostTaskID`, `RevenueTaskID`, `CostCodeID`, `VendorID`, `CustomerID`, `SecondaryVendorID`, `Subcontract`, `BillID`, `InvoiceID`, payment refs | Compliance/lien-waiver/payment-control state | Many nullable reference fields; do not assume one universal join path |
| `ComplianceDocumentBill` | `CompanyID + ComplianceDocumentID + DocType + RefNbr + LineNbr` | AP bill doc type/ref/line | Compliance-to-AP bill relation | Must include DocType and LineNbr |
| `ComplianceDocumentReference` | `CompanyID + ComplianceDocumentReferenceId` | `RefNoteId`, `Type`, `ReferenceNumber` | NoteID-based source references | ReferenceNumber is not enough without type and NoteID context |
| `ComplianceAttribute`, `ComplianceAttributeType` | identity/code-specific keys | ComplianceDocument type/configuration | Compliance attribute metadata | Setup/configuration, not document state |
| `LienWaiverSetup`, `LienWaiverRecipient` | setup-specific keys | project/vendor/payment context through processing logic | Lien waiver generation policy | Generation logic is not fully visible from setup rows alone |
| `JointPayee` | `CompanyID + JointPayeeID` | `APDocType + APRefNbr + APLineNbr`, `JointPayeeInternalID` | Joint check split for AP bill line | AP bill remains source payable document |
| `JointPayeePayment` | `CompanyID + JointPayeePaymentId` | `JointPayeeID`, payment doc type/ref, invoice doc type/ref | Joint payee amount assigned to AP payment | Payment state must be checked in AP/CA as well |

**Key rule:** CN compliance and joint-check tables control eligibility, lien-waiver, and shared-payment behavior. They do not create project actuals by themselves and they do not replace AP/AR/CA ownership.

---

### PJ - Project Management Physical Tables

PJ tables store field and document coordination evidence. Most PJ headers are anchored to `ProjectId` and often `ProjectTaskId`, with `NoteID` used for attachments, activities, and Project Files links.

| Table / Family | Primary Key | Main Join Anchors | Diagnostic Use | Common Pitfall |
|---|---|---|---|---|
| `ProjectIssue` | `ProjectIssueId + CompanyID` | `ProjectId + ProjectTaskId`, `ConvertedTo`, `RelatedEntityId`, `NoteID` | Site issue, cost/schedule impact, conversion evidence | Impact fields are evidence, not posted financial impact |
| `RequestForInformation` | `CompanyID + RequestForInformationId` | `ProjectId + ProjectTaskId`, business account/contact, `ConvertedTo`, `ConvertedFrom`, `NoteID` | Clarification workflow and conversion evidence | RFI answer does not update budget unless separate change flow exists |
| `DailyFieldReport` | `CompanyID + DailyFieldReportId`; unique `DailyFieldReportCd` | `ProjectId`, `ProjectManagerId`, status flags, `NoteID` | Daily site record and field evidence | Header alone is incomplete; inspect relation/detail tables |
| `DailyFieldReport*` relation/detail tables | identity per detail table | `DailyFieldReportId` plus target ID/ref | Links to issues, change requests/orders, progress worksheets, photos, receipts, labor, equipment, visitors, weather, notes | Relation tables often store target IDs without full business context |
| `DrawingLog`, `DrawingLogRevision`, `DrawingLogDiscipline`, `DrawingLogStatus` | drawing/status-specific keys | `ProjectId + ProjectTaskId`, revision/original drawing, `NoteID` | Drawing register and revision context | `IsCurrent` matters for revision interpretation |
| `PhotoLog`, `Photo` | log/photo-specific keys | `ProjectId + ProjectTaskId`, `PhotoLogId`, `NoteID` | Visual evidence and progress context | Photo evidence is not project transaction state |
| `PJSubmittal`, `PJSubmittalWorkflowItem`, `PJSubmittalType` | `CompanyID + SubmittalID + RevisionID` for submittal | `ProjectId + ProjectTaskId + CostCodeID`, workflow contact/line, `IsLastRevision` | Submittal review package and revision workflow | Always account for RevisionID and `IsLastRevision` |
| `ProjectManagementSetup`, `ProjectManagementClass*`, status/setup tables | setup-specific keys | numbering, assignment/approval maps, status config | Defaults and workflow setup for PJ documents | Setup rows are not document records |
| `WeatherIntegrationSetup`, `WeatherProcessingLog` | setup/log keys | Daily Field Report weather processing | Weather context for daily reports | Weather is operational evidence, not financial state |

**Key rule:** PJ tables explain or initiate business consequences. They are normally evidence for PM/CN flows, not the persisted location of budget, commitment, actual, AR/AP, or GL outcomes.

---

### Cross-Module Tables Referenced by PM

The following tables are documented in DATABASE_MODEL.md. Key PM-relevant fields are highlighted here.

#### ARRegister / ARInvoice / ARTran

- **PM-relevant fields on ARRegister:** `ProjectID` (FK?PMProject), `BatchNbr` (FK?Batch)
- **PM-relevant fields on ARTran:** `ProjectID`, `TaskID`, `CostCodeID`, `AccountGroupID` — these determine which PMBudget line is affected
- **Linkage from PMProforma:** `PMProforma.ARInvoiceDocType + ARInvoiceRefNbr ? ARRegister.DocType + RefNbr`

#### APRegister / APInvoice / APTran

- **PM-relevant fields on APTran:** `ProjectID`, `TaskID`, `CostCodeID`, `AccountGroupID` — cost budget impact
- **Commitment consumption:** AP bill release updates PMCommitment.InvoicedQty/InvoicedAmount

#### POOrder / POLine

- **Subcontract:** POOrder with `OrderType = 'RS'`
- **PM-relevant fields on POLine:** `ProjectID`, `TaskID`, `CostCodeID`, `ExpenseAcctID` (maps to account group), `CommitmentID` (GUID ? PMCommitment)
- **Commitment creation:** When a PO with project lines is opened, PMCommitment records are created

#### GLTran / Batch

- **PM-relevant fields on GLTran:** `ProjectID`, `TaskID`, `CostCodeID`, `AccountID` (determines account group)
- **PMTran.BatchNbr ? Batch.BatchNbr** (with Module)

---

## 8. Cross-Module Process Flows

### Flow 1: Project Budget ? Commitment ? PO ? Receipt ? AP Bill ? PM/GL Effect

**Business Narrative:** A project has a cost budget. A purchase order (or subcontract) is created for materials/services. The PO creates commitments. Goods are received. An AP bill is created against the receipt. The bill is released, creating cost transactions and GL entries.

**Source Tables ? Transition Tables ? Final Tables:**

```
PMBudget (cost budget line)
    ? commitment amounts
POOrder + POLine (PO/Subcontract)
    ? PMCommitment (created when PO opened)
    ? PMBudget.CommittedQty/Amount updated

POReceipt + POReceiptLine (goods received)
    ? PMCommitment.ReceivedQty updated
    ? PMBudget.CommittedReceivedQty updated

APRegister + APInvoice + APTran (AP bill released)
    ? PMTran created (cost transaction)
    ? PMBudget.ActualQty/CuryActualAmount updated
    ? PMCommitment.InvoicedQty/InvoicedAmount updated
    ? PMBudget.CommittedInvoicedQty updated
    ? PMBudget.CommittedOpenQty recalculated
    ? PMHistory updated (period-to-date)
    ? Batch + GLTran created (GL posting)
```

**Authoritative Linkage Fields:**

| From | To | Link Field(s) |
|---|---|---|
| POLine | PMCommitment | POLine.CommitmentID = PMCommitment.CommitmentID (GUID) |
| PMCommitment | PMBudget | Same key dimensions: ProjectID + TaskID + AccountGroupID + CostCodeID + InventoryID |
| APTran | PMTran | PMTran.OrigTranType + OrigRefNbr ? APRegister.DocType + RefNbr |
| PMTran | PMBudget | Same key dimensions (ProjectID + TaskID + AccountGroupID + CostCodeID + InventoryID) |
| PMTran | Batch | PMTran.BatchNbr ? Batch.BatchNbr (Module = PMTran.TranType) |

**SQL Verification Strategy:**
```sql
-- Verify commitment matches PO line
SELECT c.CommitmentID, c.ProjectID, c.Qty, c.Amount, c.InvoicedQty, c.InvoicedAmount,
       pol.OrderType, pol.OrderNbr, pol.LineNbr, pol.OrderQty, pol.CuryLineAmt
FROM PMCommitment c
JOIN POLine pol ON c.CompanyID = pol.CompanyID AND c.CommitmentID = pol.CommitmentID
WHERE c.CompanyID = @CompanyID AND c.ProjectID = @ProjectID

-- Verify budget commitment totals match sum of commitments
SELECT b.ProjectID, b.ProjectTaskID, b.AccountGroupID, b.CostCodeID, b.InventoryID,
       b.CommittedQty, b.CuryCommittedAmount, b.CommittedOpenQty, b.CuryCommittedOpenAmount,
       SUM(c.Qty) AS TotalCommittedQty, SUM(c.Amount) AS TotalCommittedAmt
FROM PMBudget b
LEFT JOIN PMCommitment c ON b.CompanyID = c.CompanyID
    AND b.ProjectID = c.ProjectID AND b.ProjectTaskID = c.ProjectTaskID
    AND b.AccountGroupID = c.AccountGroupID AND b.CostCodeID = c.CostCodeID
    AND b.InventoryID = c.InventoryID
WHERE b.CompanyID = @CompanyID AND b.ProjectID = @ProjectID AND b.Type = 'E'
GROUP BY b.ProjectID, b.ProjectTaskID, b.AccountGroupID, b.CostCodeID, b.InventoryID,
         b.CommittedQty, b.CuryCommittedAmount, b.CommittedOpenQty, b.CuryCommittedOpenAmount
```

---

### Flow 2: Project ? Billing ? Pro Forma ? AR Invoice

**Business Narrative:** A project is billed. The billing process creates a pro forma invoice. The pro forma is reviewed, approved, and released, which creates an AR invoice.

```
PMProject (billable project with customer)
    ? PMTask (tasks with billing rules)
    ? PMTran (unbilled transactions, for T&M billing)
    ? PMBudget (completion %, for progress billing)

Billing Process runs:
    ? PMProforma created
    ? PMProformaLine records created
    ? PMBudget.CuryInvoicedAmount updated (draft invoice amounts)
    ? PMTran.Billed = true (for T&M billing)

Pro Forma released:
    ? ARRegister + ARInvoice created
    ? PMProforma.ARInvoiceDocType + ARInvoiceRefNbr populated
    ? PMBillingRecord created

AR Invoice released:
    ? PMTran created (revenue transactions)
    ? PMBudget.ActualQty/CuryActualAmount updated (revenue side)
    ? PMHistory updated
    ? Batch + GLTran created
```

**Authoritative Linkage Fields:**

| From | To | Link Field(s) |
|---|---|---|
| PMProforma | ARInvoice | PMProforma.ARInvoiceDocType + ARInvoiceRefNbr ? ARRegister.DocType + RefNbr |
| PMProforma | PMProject | PMProforma.ProjectID ? PMProject.ContractID |
| PMProformaLine | PMBudget | Key dimensions: ProjectID + TaskID + AccountGroupID + CostCodeID + InventoryID |
| PMBillingRecord | PMProforma | PMBillingRecord.ProformaRefNbr ? PMProforma.RefNbr |
| ARTran | PMTran | PMTran.ARTranType + ARRefNbr ? ARTran.TranType + RefNbr |

---

### Flow 3: Change Order ? Budget Revision + Commitment Adjustment

```
PMChangeRequest (optional — preliminary estimate)
    ? PMBudget.DraftChangeOrderQty/Amount updated

PMChangeOrder created:
    ? PMChangeOrderBudget lines (budget adjustments)
    ? PMChangeOrderLine lines (commitment adjustments)

Change Order released (Status ? 'C' Closed):
    ? PMBudget.ChangeOrderQty/CuryChangeOrderAmount updated
    ? PMBudget.RevisedQty/CuryRevisedAmount recalculated
    ? PMCommitment.Qty/Amount updated (commitment adjustments)
    ? PMBudget.CommittedQty/CuryCommittedAmount updated
    ? PMBudget.DraftChangeOrderQty/Amount reduced
```

---

### Flow 4: SO ? Shipment ? AR Invoice ? PM/GL Links

```
SOOrder + SOLine (with ProjectID, TaskID)
    ? SOShipment (shipment created)
    ? ARRegister + ARInvoice + ARTran created (invoice)

AR Invoice released:
    ? PMTran created for each ARTran with project reference
    ? PMBudget actuals updated
    ? GLTran created with ProjectID/TaskID
```

---

### Flow 5: Project Quote -> Project Setup

```
CRM Quote / Opportunity context
    -> PMQuote projection (not a physical SQL table)
    -> PMQuoteTask rows store proposed project task structure

Quote conversion:
    -> Contract + PMProject created or updated
    -> PMTask rows created from PMQuoteTask where applicable
    -> budget/billing setup follows project/template rules
```

**Diagnostic rule:** If a support issue says "project quote data is missing from the project," inspect CRM quote/opportunity storage plus `PMQuoteTask`, then inspect conversion logic and resulting `Contract`, `PMProject`, and `PMTask` rows. Do not query a `PMQuote` SQL table.

---

### Flow 6: Allocation, Rate, WIP, and Unbilled Control

```
PMTran / project billable basis
    -> PMAllocation + PMAllocationDetail define allocation policy
    -> allocation execution may create derived PMTran rows or audit rows
    -> PMUnbilledDailySummary may aggregate daily unbilled state
    -> PMWipAdjustment + PMWipAdjustmentLine may record WIP timing adjustment
    -> GL/AR consequence remains owned by GL/AR flows
```

**Diagnostic rule:** Treat these as derived control layers. Always trace back to source `PMTran`, project budget dimensions, and final `Batch`/`GLTran` or `ARRegister` evidence before concluding that financial truth changed.

---

### Flow 7: Construction Compliance and Joint Payment Control

```
Project / subcontract / AP bill / payment candidate
    -> ComplianceDocument records required/received/expired/blocking state
    -> ComplianceDocumentBill or reference rows connect compliance to bills/source docs
    -> JointPayee splits AP bill line responsibility
    -> JointPayeePayment connects joint payee amount to AP payment
    -> AP/CA settlement remains the financial payment truth
```

**Diagnostic rule:** Start from `ProjectID`, `VendorID`, AP bill doc type/ref/line, or payment doc type/ref. Compliance and joint-payee tables explain payment eligibility and split behavior; they do not replace AP document status or payment release state.

---

### Flow 8: PJ Field Evidence -> PM/CN Consequence

```
ProjectIssue / RFI / DailyFieldReport / DrawingLog / PhotoLog / Submittal
    -> anchored by ProjectId and optional ProjectTaskId
    -> related by NoteID, ConvertedTo/ConvertedFrom, or DailyFieldReport relation tables
    -> may initiate Change Request, Change Order, Progress Worksheet, Compliance review, or billing context
    -> PM/CN financial consequence is stored in the target PM/CN/AR/AP tables
```

**Diagnostic rule:** PJ rows explain field reality and document workflow. Use them to find the originating event or evidence, then follow the converted/linked target document to prove budget, commitment, billing, or payment impact.

---

## 9. Canonical Join Maps

### Project ? Task ? Budget ? Actual Transactions

```sql
SELECT p.ContractCD AS ProjectCD, t.TaskCD, ag.GroupCD AS AccountGroupCD,
       cc.CostCodeCD, ii.InventoryCD,
       b.CuryRevisedAmount, b.CuryActualAmount, b.CuryCommittedAmount,
       b.CuryCommittedOpenAmount, b.CuryVarianceAmount
FROM PMBudget b
JOIN Contract p ON b.CompanyID = p.CompanyID AND b.ProjectID = p.ContractID
JOIN PMTask t ON b.CompanyID = t.CompanyID AND b.ProjectID = t.ProjectID AND b.ProjectTaskID = t.TaskID
JOIN PMAccountGroup ag ON b.CompanyID = ag.CompanyID AND b.AccountGroupID = ag.GroupID
LEFT JOIN PMCostCode cc ON b.CompanyID = cc.CompanyID AND b.CostCodeID = cc.CostCodeID
LEFT JOIN InventoryItem ii ON b.CompanyID = ii.CompanyID AND b.InventoryID = ii.InventoryID
WHERE b.CompanyID = @CompanyID AND b.ProjectID = @ProjectID
ORDER BY ag.SortOrder, t.TaskCD, cc.CostCodeCD
```

### Project ? Commitments ? PO/AP

```sql
SELECT c.CommitmentID, c.Type, c.Status,
       t.TaskCD, ag.GroupCD, cc.CostCodeCD,
       c.OrigQty, c.OrigAmount, c.Qty, c.Amount,
       c.ReceivedQty, c.InvoicedQty, c.InvoicedAmount,
       po.OrderType, po.OrderNbr, pol.LineNbr
FROM PMCommitment c
JOIN PMTask t ON c.CompanyID = t.CompanyID AND c.ProjectID = t.ProjectID AND c.ProjectTaskID = t.TaskID
JOIN PMAccountGroup ag ON c.CompanyID = ag.CompanyID AND c.AccountGroupID = ag.GroupID
LEFT JOIN PMCostCode cc ON c.CompanyID = cc.CompanyID AND c.CostCodeID = cc.CostCodeID
LEFT JOIN POLine pol ON c.CompanyID = pol.CompanyID AND c.CommitmentID = pol.CommitmentID
LEFT JOIN POOrder po ON pol.CompanyID = po.CompanyID AND pol.OrderType = po.OrderType AND pol.OrderNbr = po.OrderNbr
WHERE c.CompanyID = @CompanyID AND c.ProjectID = @ProjectID
ORDER BY t.TaskCD, ag.GroupCD
```

### Project ? AR Billing

```sql
SELECT pf.RefNbr AS ProformaRefNbr, pf.RevisionID, pf.Status AS ProformaStatus,
       pf.ARInvoiceDocType, pf.ARInvoiceRefNbr,
       ar.Status AS ARStatus, ar.CuryOrigDocAmt, ar.CuryDocBal, ar.Released AS ARReleased
FROM PMProforma pf
LEFT JOIN ARRegister ar ON pf.CompanyID = ar.CompanyID
    AND pf.ARInvoiceDocType = ar.DocType AND pf.ARInvoiceRefNbr = ar.RefNbr
WHERE pf.CompanyID = @CompanyID AND pf.ProjectID = @ProjectID AND pf.Corrected = 0
ORDER BY pf.InvoiceDate DESC
```

### Project ? GL Impact

```sql
SELECT pt.TranID, pt.TranType, pt.RefNbr AS PMRefNbr,
       pt.BatchNbr, pt.OrigModule, pt.OrigTranType, pt.OrigRefNbr,
       t.TaskCD, ag.GroupCD,
       pt.TranCuryAmount, pt.Amount, pt.ProjectCuryAmount,
       pt.Released, pt.Billed, pt.Allocated
FROM PMTran pt
JOIN PMTask t ON pt.CompanyID = t.CompanyID AND pt.ProjectID = t.ProjectID AND pt.TaskID = t.TaskID
JOIN PMAccountGroup ag ON pt.CompanyID = ag.CompanyID AND pt.AccountGroupID = ag.GroupID
WHERE pt.CompanyID = @CompanyID AND pt.ProjectID = @ProjectID AND pt.Released = 1
ORDER BY pt.Date DESC, pt.TranID
```

### Project -> Project Files / Linked Evidence

```sql
SELECT pe.ProjectID,
       pe.LinkType,
       pe.LinkedDocumentType,
       pe.LinkedDocumentNoteID,
       pe.LinkedEntityNoteID,
       pe.CreatedDateTime,
       pe.LastModifiedDateTime
FROM PMProjectEntity pe
WHERE pe.CompanyID = @CompanyID
  AND pe.ProjectID = @ProjectID
ORDER BY pe.LastModifiedDateTime DESC
```

Use `LinkedDocumentNoteID` and `LinkedEntityNoteID` to continue into the owning document/entity or file/attachment context. The table itself proves a project-file/entity link, not the business state of the linked document.

### Project -> PJ Field Documents

```sql
-- Project issues and RFIs anchored to the same project/task dimensions.
SELECT 'Issue' AS Source, pi.ProjectIssueCd AS RefNbr, pi.ProjectId, pi.ProjectTaskId,
       pi.Status, pi.MajorStatus, pi.IsCostImpact, pi.CostImpact,
       pi.IsScheduleImpact, pi.ScheduleImpact, pi.ConvertedTo, pi.NoteID
FROM ProjectIssue pi
WHERE pi.CompanyID = @CompanyID AND pi.ProjectId = @ProjectID

UNION ALL

SELECT 'RFI' AS Source, rfi.RequestForInformationCd AS RefNbr, rfi.ProjectId, rfi.ProjectTaskId,
       rfi.Status, rfi.MajorStatus, rfi.IsCostImpact, rfi.CostImpact,
       rfi.IsScheduleImpact, rfi.ScheduleImpact, rfi.ConvertedTo, rfi.NoteID
FROM RequestForInformation rfi
WHERE rfi.CompanyID = @CompanyID AND rfi.ProjectId = @ProjectID
```

For daily field reports, query the header first and then relation tables:

```sql
SELECT dfr.DailyFieldReportId, dfr.DailyFieldReportCd, dfr.Date,
       dfr.Status, dfr.Hold, dfr.Approved, dfr.Rejected, dfr.NoteID
FROM DailyFieldReport dfr
WHERE dfr.CompanyID = @CompanyID AND dfr.ProjectId = @ProjectID

-- Example relation: daily report to project issue
SELECT rel.DailyFieldReportId, rel.ProjectIssueId, pi.ProjectIssueCd, pi.Status
FROM DailyFieldReportProjectIssue rel
JOIN ProjectIssue pi ON rel.CompanyID = pi.CompanyID
    AND rel.ProjectIssueId = pi.ProjectIssueId
WHERE rel.CompanyID = @CompanyID
  AND rel.DailyFieldReportId = @DailyFieldReportId
```

### Project -> Compliance / Joint Payment

```sql
SELECT cd.ComplianceDocumentID,
       cd.ProjectID,
       cd.VendorID,
       cd.SecondaryVendorID,
       cd.CustomerID,
       cd.DocumentType,
       cd.Status,
       cd.Required,
       cd.Received,
       cd.ExpirationDate,
       cd.Subcontract,
       cd.BillID,
       cd.InvoiceID,
       cd.ApCheckID,
       cd.ArPaymentID
FROM ComplianceDocument cd
WHERE cd.CompanyID = @CompanyID
  AND cd.ProjectID = @ProjectID
```

```sql
-- Joint payees for an AP bill line.
SELECT jp.JointPayeeID,
       jp.APDocType,
       jp.APRefNbr,
       jp.APLineNbr,
       jp.JointPayeeInternalID,
       jp.JointPayeeExternalName,
       jp.CuryJointAmountOwed,
       jp.CuryJointAmountPaid,
       jp.CuryJointBalance,
       jpp.PaymentDocType,
       jpp.PaymentRefNbr,
       jpp.CuryJointAmountToPay,
       jpp.IsVoided
FROM JointPayee jp
LEFT JOIN JointPayeePayment jpp ON jp.CompanyID = jpp.CompanyID
    AND jp.JointPayeeID = jpp.JointPayeeID
WHERE jp.CompanyID = @CompanyID
  AND jp.APDocType = @APDocType
  AND jp.APRefNbr = @APRefNbr
  AND jp.APLineNbr = @APLineNbr
```

---

## 10. Status, Type, and Lifecycle Reference

### Project Lifecycle

```
Planned (D) ? [Approve] ? Active (A) ? [Complete] ? Completed (C) ? [Close] ? Closed (L)
                              ?                           ?
                        Suspended (E)              Can be reopened
                              ?
                        Cancelled (X)

With Approval:
On Hold (H) ? Pending Approval (I) ? Active (A)
                      ?
                  Rejected (J)
```

### Task Lifecycle

```
Planned (D) ? Active (A) ? Completed (F)
                  ?
              Canceled (C)
```

### Change Order Lifecycle

```
On Hold (H) ? [Remove Hold] ? Open (O) ? [Close] ? Closed (C)
      ?                                      
Pending Approval (A) ? Open (O)               
      ?                                       
  Rejected (R)                                
```

### Pro Forma Lifecycle

```
On Hold (H) ? [Remove Hold] ? Open (O) ? [Release] ? Closed (C)
      ?                                      
Pending Approval (A) ? Open (O)               
      ?                                       
  Rejected (R)                                

Release creates AR Invoice (ARInvoiceDocType + ARInvoiceRefNbr populated)
```

### PMAccountGroup Types

| Type | Value | Budget Tab | Description |
|---|---|---|---|
| Asset | 'A' | Cost | Balance sheet — asset |
| Liability | 'L' | Cost | Balance sheet — liability |
| Income | 'I' | Revenue | Income statement — revenue |
| Expense | 'E' | Cost | Income statement — cost |
| Off-Balance | 'O' | Cost | Non-financial tracking |

### PMAccountGroup Report Groups (Construction)

| Value | Description |
|---|---|
| 'L' | Labor |
| 'M' | Material |
| 'S' | Subcontract |
| 'E' | Equipment |
| 'O' | Other |
| 'R' | Revenue |

### PMCommitment Types

| Value | Description |
|---|---|
| 'I' | Internal (from PO/Subcontract) |
| 'E' | External (manual) |

### PMCommitment Statuses

| Value | Description |
|---|---|
| 'O' | Open |
| 'C' | Closed |

### PMBudget Type (from Account Group)

| Value | Description | Budget Tab |
|---|---|---|
| 'E' | Expense | Cost Budget |
| 'A' | Asset | Cost Budget |
| 'L' | Liability | Cost Budget |
| 'I' | Income | Revenue Budget |
| 'O' | Off-Balance | Cost Budget |

### Budget Level Values

| Value | Description |
|---|---|
| 'T' | Task only |
| 'I' | Task and Item |
| 'C' | Task and Cost Code |
| 'D' | Task, Item, and Cost Code |

---

## 11. SQL Verification Playbook for Support Agents

### Symptom: "Project budget amount shown on screen looks wrong"

**Likely Tables:** PMBudget, PMHistory, PMTran  
**Likely Failure Points:** Currency mismatch, wrong budget type filter, computed vs persisted field confusion

**SQL Verification Sequence:**

1. Check PMBudget raw values:
```sql
SELECT b.*, ag.GroupCD, ag.Type, t.TaskCD
FROM PMBudget b
JOIN PMAccountGroup ag ON b.CompanyID = ag.CompanyID AND b.AccountGroupID = ag.GroupID
JOIN PMTask t ON b.CompanyID = t.CompanyID AND b.ProjectID = t.ProjectID AND b.ProjectTaskID = t.TaskID
WHERE b.CompanyID = @CompanyID AND b.ProjectID = @ProjectID
```

2. Verify actuals match sum of released transactions:
```sql
SELECT pt.TaskID, pt.AccountGroupID, pt.CostCodeID, pt.InventoryID,
       SUM(pt.ProjectCuryAmount) AS TranProjectCuryTotal,
       SUM(pt.Amount) AS TranBaseTotal
FROM PMTran pt
WHERE pt.CompanyID = @CompanyID AND pt.ProjectID = @ProjectID AND pt.Released = 1
GROUP BY pt.TaskID, pt.AccountGroupID, pt.CostCodeID, pt.InventoryID
```

3. Compare with PMBudget.CuryActualAmount — discrepancies indicate a balance update issue.

**Caveats:**
- `CuryActualAmount` is in **project currency**; `ActualAmount` may be in base currency
- `CuryVarianceAmount` and `Performance` are **computed (not persisted)** — recalculated from persisted fields
- The UI may show calculated values that include formulas not stored in the database

---

### Symptom: "Commitment not relieved / committed open amount wrong"

**Likely Tables:** PMCommitment, PMBudget, POLine, APTran

```sql
-- Check commitment detail
SELECT c.*, t.TaskCD, ag.GroupCD
FROM PMCommitment c
JOIN PMTask t ON c.CompanyID = t.CompanyID AND c.ProjectID = t.ProjectID AND c.ProjectTaskID = t.TaskID
JOIN PMAccountGroup ag ON c.CompanyID = ag.CompanyID AND c.AccountGroupID = ag.GroupID
WHERE c.CompanyID = @CompanyID AND c.ProjectID = @ProjectID

-- Check if AP bills were released against the PO
SELECT apt.ProjectID, apt.TaskID, apt.TranType, apt.RefNbr, apt.LineNbr,
       apt.CuryTranAmt, apt.POOrderType, apt.PONbr, apt.POLineNbr
FROM APTran apt
WHERE apt.CompanyID = @CompanyID AND apt.ProjectID = @ProjectID
  AND apt.Released = 1

-- Check PMBudget committed invoiced vs commitment invoiced
SELECT b.ProjectTaskID, b.AccountGroupID, b.CuryCommittedInvoicedAmount,
       SUM(c.InvoicedAmount) AS CommitmentInvoicedTotal
FROM PMBudget b
LEFT JOIN PMCommitment c ON b.CompanyID = c.CompanyID
    AND b.ProjectID = c.ProjectID AND b.ProjectTaskID = c.ProjectTaskID
    AND b.AccountGroupID = c.AccountGroupID
WHERE b.CompanyID = @CompanyID AND b.ProjectID = @ProjectID AND b.Type = 'E'
GROUP BY b.ProjectTaskID, b.AccountGroupID, b.CuryCommittedInvoicedAmount
```

---

### Symptom: "Transaction exists in UI but not in expected table"

**Likely Issue:** The value may come from a projection DAC, not a physical table. Or the transaction may not be released yet.

```sql
-- Check PMTran for the specific reference
SELECT * FROM PMTran
WHERE CompanyID = @CompanyID AND OrigRefNbr = @DocRefNbr AND OrigTranType = @DocType

-- Check if the source document is released
SELECT DocType, RefNbr, Released, Status FROM ARRegister
WHERE CompanyID = @CompanyID AND DocType = @DocType AND RefNbr = @RefNbr
```

---

### Symptom: "Billing amount differs from project balance"

**Likely Tables:** PMBudget, PMProforma, PMProformaLine, ARRegister

```sql
-- Check pro forma totals vs budget invoiced amounts
SELECT pf.RefNbr, pf.Status, pf.ARInvoiceDocType, pf.ARInvoiceRefNbr,
       SUM(pl.CuryLineTotal) AS ProformaLineTotal
FROM PMProforma pf
JOIN PMProformaLine pl ON pf.CompanyID = pl.CompanyID AND pf.RefNbr = pl.RefNbr AND pf.RevisionID = pl.RevisionID
WHERE pf.CompanyID = @CompanyID AND pf.ProjectID = @ProjectID AND pf.Corrected = 0
GROUP BY pf.RefNbr, pf.Status, pf.ARInvoiceDocType, pf.ARInvoiceRefNbr

-- Check revenue budget invoiced/actual amounts
SELECT b.ProjectTaskID, b.AccountGroupID,
       b.CuryInvoicedAmount AS DraftInvoiceAmt,
       b.CuryActualAmount AS ReleasedActualAmt,
       b.CuryAmountToInvoice AS PendingInvoiceAmt,
       b.CompletedPct
FROM PMBudget b
WHERE b.CompanyID = @CompanyID AND b.ProjectID = @ProjectID AND b.Type = 'I'
```

---

### Symptom: "AR/AP document linked to project but project totals did not update"

**Check:** Was the document released? Is the project/task/account mapping correct?

```sql
-- Check PMTran for the document
SELECT pt.TranID, pt.ProjectID, pt.TaskID, pt.AccountGroupID,
       pt.OrigTranType, pt.OrigRefNbr, pt.Released, pt.Amount
FROM PMTran pt
WHERE pt.CompanyID = @CompanyID
  AND pt.OrigRefNbr = @DocRefNbr
  AND pt.OrigTranType = @DocType

-- If no PMTran found, check if the document lines have project references
SELECT DocType, RefNbr, LineNbr, ProjectID, TaskID, AccountID
FROM ARTran  -- or APTran
WHERE CompanyID = @CompanyID AND RefNbr = @DocRefNbr AND DocType = @DocType  -- use TranType for ARTran
```

---

### Symptom: "GL impact exists / does not exist for project transaction"

```sql
-- From PMTran, get the BatchNbr
SELECT pt.TranID, pt.BatchNbr, pt.TranType, pt.AccountID, pt.SubID,
       pt.OffsetAccountID, pt.OffsetSubID
FROM PMTran pt
WHERE pt.CompanyID = @CompanyID AND pt.TranID = @TranID

-- Check GL batch and transactions
SELECT gt.Module, gt.BatchNbr, gt.LineNbr, gt.AccountID, gt.SubID,
       gt.DebitAmt, gt.CreditAmt, gt.ProjectID, gt.TaskID
FROM GLTran gt
WHERE gt.CompanyID = @CompanyID AND gt.BatchNbr = @BatchNbr AND gt.Module = @Module
```

---

### Symptom: "Wrong project/task/cost code on posted transaction"

```sql
-- Check GLTran project references
SELECT gt.Module, gt.BatchNbr, gt.LineNbr,
       gt.ProjectID, gt.TaskID, gt.CostCodeID,
       gt.AccountID, gt.DebitAmt, gt.CreditAmt,
       gt.TranDesc, gt.RefNbr AS SourceRefNbr
FROM GLTran gt
WHERE gt.CompanyID = @CompanyID AND gt.BatchNbr = @BatchNbr
  AND gt.ProjectID = @ProjectID

-- Cross-reference with PMTran
SELECT pt.TranID, pt.ProjectID, pt.TaskID, pt.AccountGroupID, pt.CostCodeID,
       pt.OrigTranType, pt.OrigRefNbr, pt.OrigLineNbr
FROM PMTran pt
WHERE pt.CompanyID = @CompanyID AND pt.BatchNbr = @BatchNbr
```

---

### Symptom: "Project quote task did not become a project task"

**Likely Tables:** CRM quote/opportunity tables, PMQuoteTask, Contract, PMProject, PMTask

```sql
-- PMQuote itself is a projection. Start with persisted quote tasks.
SELECT qt.QuoteID, qt.TaskCD, qt.Description, qt.IsDefault, qt.Type,
       qt.PlannedStartDate, qt.PlannedEndDate
FROM PMQuoteTask qt
WHERE qt.CompanyID = @CompanyID AND qt.QuoteID = @QuoteID

-- Then compare with resulting project tasks.
SELECT t.ProjectID, t.TaskID, t.TaskCD, t.Description, t.IsDefault
FROM PMTask t
WHERE t.CompanyID = @CompanyID AND t.ProjectID = @ProjectID
```

**Caveat:** Missing rows may be caused by conversion logic, template behavior, or CRM quote data, not only by `PMQuoteTask` storage.

---

### Symptom: "Compliance or joint check blocks payment unexpectedly"

**Likely Tables:** ComplianceDocument, ComplianceDocumentBill, JointPayee, JointPayeePayment, APRegister/APTran, APPayment/APAdjust

```sql
SELECT cd.ComplianceDocumentID, cd.Required, cd.Received, cd.Status,
       cd.ProjectID, cd.VendorID, cd.SecondaryVendorID,
       cdb.DocType, cdb.RefNbr, cdb.LineNbr
FROM ComplianceDocument cd
LEFT JOIN ComplianceDocumentBill cdb ON cd.CompanyID = cdb.CompanyID
    AND cd.ComplianceDocumentID = cdb.ComplianceDocumentID
WHERE cd.CompanyID = @CompanyID
  AND (cd.ProjectID = @ProjectID OR cdb.RefNbr = @APRefNbr)

SELECT jp.JointPayeeID, jp.APDocType, jp.APRefNbr, jp.APLineNbr,
       jp.JointPayeeInternalID, jp.JointPayeeExternalName,
       jp.CuryJointAmountOwed, jp.CuryJointAmountPaid, jp.CuryJointBalance
FROM JointPayee jp
WHERE jp.CompanyID = @CompanyID
  AND jp.APDocType = @APDocType
  AND jp.APRefNbr = @APRefNbr
```

**Caveat:** These tables explain eligibility and split-payment control. Payment release, voiding, and cash settlement must still be verified through AP/CA tables.

---

### Symptom: "Field document exists but no financial impact is visible"

**Likely Tables:** ProjectIssue, RequestForInformation, DailyFieldReport, DailyFieldReport* relation tables, PMChangeRequest, PMChangeOrder, PMProgressWorksheet

```sql
SELECT pi.ProjectIssueId, pi.ProjectIssueCd, pi.Status, pi.ConvertedTo,
       pi.IsCostImpact, pi.CostImpact, pi.IsScheduleImpact, pi.ScheduleImpact
FROM ProjectIssue pi
WHERE pi.CompanyID = @CompanyID AND pi.ProjectId = @ProjectID

SELECT rfi.RequestForInformationId, rfi.RequestForInformationCd, rfi.Status,
       rfi.ConvertedTo, rfi.ConvertedFrom, rfi.IsCostImpact, rfi.CostImpact
FROM RequestForInformation rfi
WHERE rfi.CompanyID = @CompanyID AND rfi.ProjectId = @ProjectID
```

**Caveat:** PJ cost/schedule impact fields are evidence and workflow context. Confirm actual financial impact in the converted PM change, progress, billing, commitment, or transaction tables.

---

### Symptom: "WIP or unbilled amount does not match source activity"

**Likely Tables:** PMUnbilledDailySummary, PMWipAdjustment, PMWipAdjustmentLine, PMTran, PMBudget, Batch/GLTran

```sql
SELECT uds.ProjectID, uds.TaskID, uds.AccountGroupID, uds.Date,
       uds.Billable, uds.NonBillable
FROM PMUnbilledDailySummary uds
WHERE uds.CompanyID = @CompanyID AND uds.ProjectID = @ProjectID
ORDER BY uds.Date DESC

SELECT w.RefNbr, w.Status, w.Released, w.BatchNbr,
       w.CuryOverbillingAmount, w.CuryUnderbillingAmount,
       w.CuryOverbillingAdjustmentAmount, w.CuryUnderbillingAdjustmentAmount
FROM PMWipAdjustment w
WHERE w.CompanyID = @CompanyID
  AND (w.RefNbr = @WipRefNbr OR w.BatchNbr = @BatchNbr)
```

**Caveat:** WIP and unbilled tables are derived control/accounting views. Trace to `PMTran`, budget dimensions, and GL/AR outcome before concluding the source activity is wrong.

---

## 12. High-Value Query Templates

### Template 1: Complete Project Budget Summary

```sql
-- Returns all budget lines with human-readable keys and all balance fields
SELECT
    p.ContractCD AS ProjectCD,
    t.TaskCD,
    ag.GroupCD AS AccountGroupCD,
    ag.Type AS AccountGroupType,
    ag.ReportGroup,
    CASE WHEN cc.CostCodeID = 0 THEN 'N/A' ELSE cc.CostCodeCD END AS CostCodeCD,
    CASE WHEN ii.InventoryID = 0 THEN 'N/A' ELSE ii.InventoryCD END AS InventoryCD,
    b.CuryAmount AS OrigBudgetedAmt,
    b.CuryRevisedAmount AS RevisedBudgetedAmt,
    b.CuryChangeOrderAmount AS COAmount,
    b.CuryActualAmount AS ActualAmt,
    b.CuryCommittedAmount AS CommittedAmt,
    b.CuryCommittedOpenAmount AS CommittedOpenAmt,
    b.CuryCommittedInvoicedAmount AS CommittedInvoicedAmt,
    b.CuryInvoicedAmount AS DraftInvoiceAmt,
    b.CompletedPct,
    b.CuryAmountToInvoice AS PendingInvoiceAmt
FROM PMBudget b
JOIN Contract p ON b.CompanyID = p.CompanyID AND b.ProjectID = p.ContractID
JOIN PMTask t ON b.CompanyID = t.CompanyID AND b.ProjectID = t.ProjectID AND b.ProjectTaskID = t.TaskID
JOIN PMAccountGroup ag ON b.CompanyID = ag.CompanyID AND b.AccountGroupID = ag.GroupID
LEFT JOIN PMCostCode cc ON b.CompanyID = cc.CompanyID AND b.CostCodeID = cc.CostCodeID
LEFT JOIN InventoryItem ii ON b.CompanyID = ii.CompanyID AND b.InventoryID = ii.InventoryID
WHERE b.CompanyID = @CompanyID AND b.ProjectID = @ProjectID
ORDER BY ag.Type, ag.SortOrder, t.TaskCD, cc.CostCodeCD
```

### Template 2: Project Transactions with Source Document Lineage

```sql
-- Returns released project transactions with full source document tracing
SELECT
    pt.TranID,
    pt.Date,
    pt.FinPeriodID,
    t.TaskCD,
    ag.GroupCD AS AccountGroupCD,
    pt.Description,
    pt.TranCuryAmount,
    pt.ProjectCuryAmount,
    pt.Amount AS BaseAmount,
    pt.TranCuryID AS Currency,
    pt.Qty,
    pt.Released,
    pt.Billed,
    pt.Allocated,
    pt.TranType AS PMModule,
    pt.RefNbr AS PMBatchRefNbr,
    pt.BatchNbr AS GLBatchNbr,
    pt.OrigModule,
    pt.OrigTranType,
    pt.OrigRefNbr,
    pt.OrigLineNbr
FROM PMTran pt
JOIN PMTask t ON pt.CompanyID = t.CompanyID AND pt.ProjectID = t.ProjectID AND pt.TaskID = t.TaskID
JOIN PMAccountGroup ag ON pt.CompanyID = ag.CompanyID AND pt.AccountGroupID = ag.GroupID
WHERE pt.CompanyID = @CompanyID AND pt.ProjectID = @ProjectID AND pt.Released = 1
ORDER BY pt.Date, pt.TranID
```

### Template 3: Commitment Status with PO Detail

```sql
-- Returns all commitments with linked PO information and consumption status
SELECT
    c.CommitmentID,
    c.Type,
    c.Status,
    t.TaskCD,
    ag.GroupCD AS AccountGroupCD,
    c.OrigQty,
    c.OrigAmount,
    c.Qty AS RevisedQty,
    c.Amount AS RevisedAmount,
    c.ReceivedQty,
    c.InvoicedQty,
    c.InvoicedAmount,
    (c.Qty - c.InvoicedQty) AS OpenQty,
    (c.Amount - c.InvoicedAmount) AS OpenAmount,
    po.OrderType AS POType,
    po.OrderNbr AS PONbr,
    pol.LineNbr AS POLineNbr,
    po.Status AS POStatus,
    ba.AcctCD AS VendorCD,
    ba.AcctName AS VendorName
FROM PMCommitment c
JOIN PMTask t ON c.CompanyID = t.CompanyID AND c.ProjectID = t.ProjectID AND c.ProjectTaskID = t.TaskID
JOIN PMAccountGroup ag ON c.CompanyID = ag.CompanyID AND c.AccountGroupID = ag.GroupID
LEFT JOIN POLine pol ON c.CompanyID = pol.CompanyID AND c.CommitmentID = pol.CommitmentID
LEFT JOIN POOrder po ON pol.CompanyID = po.CompanyID AND pol.OrderType = po.OrderType AND pol.OrderNbr = po.OrderNbr
LEFT JOIN BAccount ba ON po.CompanyID = ba.CompanyID AND po.VendorID = ba.BAccountID
WHERE c.CompanyID = @CompanyID AND c.ProjectID = @ProjectID
ORDER BY t.TaskCD, ag.GroupCD
```

### Template 4: Change Order Impact Analysis

```sql
-- Returns change orders and their budget/commitment impact
SELECT
    co.RefNbr AS ChangeOrderNbr,
    co.Description,
    co.Status,
    co.Date,
    -- Budget impact
    cob.LineNbr,
    t.TaskCD,
    ag.GroupCD AS AccountGroupCD,
    cob.Qty AS COBudgetQty,
    cob.CuryAmount AS COBudgetAmount
FROM PMChangeOrder co
JOIN PMChangeOrderBudget cob ON co.CompanyID = cob.CompanyID AND co.RefNbr = cob.RefNbr
JOIN PMTask t ON cob.CompanyID = t.CompanyID AND cob.ProjectID = t.ProjectID AND cob.ProjectTaskID = t.TaskID
JOIN PMAccountGroup ag ON cob.CompanyID = ag.CompanyID AND cob.AccountGroupID = ag.GroupID
WHERE co.CompanyID = @CompanyID AND co.ProjectID = @ProjectID
ORDER BY co.RefNbr, cob.LineNbr
```

### Template 5: Pro Forma to AR Invoice Tracing

```sql
-- Traces pro forma invoices to AR documents
SELECT
    pf.RefNbr AS ProformaRefNbr,
    pf.RevisionID,
    pf.InvoiceDate,
    pf.Status AS ProformaStatus,
    pf.Corrected,
    pf.ARInvoiceDocType,
    pf.ARInvoiceRefNbr,
    ar.Status AS ARStatus,
    ar.Released AS ARReleased,
    ar.CuryOrigDocAmt AS ARInvoiceTotal,
    ar.CuryDocBal AS AROpenBalance,
    pf.ReversedARInvoiceDocType,
    pf.ReversedARInvoiceRefNbr
FROM PMProforma pf
LEFT JOIN ARRegister ar ON pf.CompanyID = ar.CompanyID
    AND pf.ARInvoiceDocType = ar.DocType AND pf.ARInvoiceRefNbr = ar.RefNbr
WHERE pf.CompanyID = @CompanyID AND pf.ProjectID = @ProjectID
ORDER BY pf.InvoiceDate DESC, pf.RefNbr DESC
```

---

## 13. Common Pitfalls and False Assumptions

### 1. Joining on human-readable numbers without DocType/OrderType/CompanyID
**Risk:** Cross-type matches. Always include `DocType` + `RefNbr` (AR/AP) or `OrderType` + `OrderNbr` (PO/SO) and `CompanyID`.

### 2. Querying projection DACs as physical tables
**Risk:** `Subcontract` is **NOT** a SQL table. It is a `[PXProjection]` over `POOrder WHERE OrderType='RS'`. Query `POOrder` directly.

### 3. Ignoring extension tables
**Risk:** Querying only `Contract` without `PMProject` misses PM-specific fields (BudgetLevel, CuryID, etc.). Querying only `ARInvoice` without `ARRegister` misses amounts, customer, status.

### 4. Confusing document currency and base currency
**Risk:** `CuryActualAmount` on PMBudget is in **project currency**, not document currency. PMTran has THREE currency layers. Never mix without conversion.

### 5. Reading derived status instead of source booleans
**Risk:** Status strings are computed. Use `Released`, `Hold`, `OpenDoc`, `IsActive`, `IsCompleted` booleans instead.

### 6. Assuming UI-calculated values are persisted
**Risk:** `CuryVarianceAmount`, `CuryActualPlusOpenCommittedAmount`, `Performance`, `CommittedCOQty`, `CommittedCOAmount` on PMBudget are **computed properties, NOT persisted**. They are calculated from persisted fields at runtime. Similarly, `CommittedVarianceQty/Amount` and `CommittedCOQty/Amount` on PMCommitment are computed.

### 7. Assuming one-step lineage when flow is multi-step
**Risk:** PO ? AP bill ? PM transaction is a multi-step process. A PO being open doesn't mean cost has been recorded. Check the entire chain: PO opened ? commitment created ? receipt ? AP bill released ? PMTran created ? budget actuals updated.

### 8. Missing project/task/cost code/account group granularity
**Risk:** PMBudget has a 5-part composite key. Aggregating without all 5 parts will produce wrong totals. Especially: InventoryID = 0 means "no item" and is a valid key value, not NULL.

### 9. Ignoring retainage / billed-unbilled split semantics
**Risk:** Retainage withheld amounts are tracked on separate fields. The `CuryOrigDocAmt` on an AR invoice may not match the full project billing amount if retainage is withheld.

### 10. PMProject vs Contract table confusion
**Risk:** PMProject **extends** Contract. The ContractID is shared. Some fields (Status, CustomerID, StartDate) are on Contract; others (BudgetLevel, CuryID) are on PMProject. A query must join both or know which table owns the needed field.

### 11. Default InventoryID and CostCodeID values
**Risk:** When the inventory or cost code dimension is not used, the value is **0** (not NULL). The default "N/A" inventory item has `InventoryID = 0` and the default cost code has `CostCodeID = 0`. These are valid PK values.

### 12. Confusing PMRegister.Module with GL Batch.Module
**Risk:** PMRegister.Module indicates the source of PM transactions (PM, AR, AP, GL, IN). This is **not the same** as the GL Batch.Module. PMTran.BatchNbr links to GL Batch, but PMTran.TranType = PMRegister.Module.

### 13. Treating PMQuote as a physical SQL table
**Risk:** `PMQuote` is a projection over CRM quote/opportunity data. Use CRM quote/opportunity storage plus `PMQuoteTask` for quote-specific project tasks.

### 14. Treating allocation, WIP, or unbilled summaries as original activity
**Risk:** `PMAllocation*`, `PMWipAdjustment*`, and `PMUnbilledDailySummary` are policy/derived-control layers. Trace to source `PMTran`, budget dimensions, and GL/AR outcome before concluding source activity changed.

### 15. Treating PJ documents as financial state
**Risk:** `ProjectIssue`, `RequestForInformation`, `DailyFieldReport`, `DrawingLog`, `PhotoLog`, and `PJSubmittal` explain field reality and workflow. They do not update PMBudget, PMTran, AR/AP, or GL without a target PM/CN/AR/AP process.

### 16. Ignoring Daily Field Report relation tables
**Risk:** The DFR header is only the daily site record. Links to issues, change requests, change orders, progress worksheets, photos, receipts, labor, equipment, visitors, weather, and notes live in related `DailyFieldReport*` tables.

### 17. Assuming compliance has one universal source-document join
**Risk:** `ComplianceDocument` has many nullable anchors: project, tasks, customer, vendor, secondary vendor, subcontract, bills, invoices, payments, checks, change orders, and NoteID references. Use source type and populated fields to pick the join path.

### 18. Treating joint checks as AP ownership
**Risk:** `JointPayee` and `JointPayeePayment` split or control payment to joint payees, but AP bills/payments and CA settlement remain in AP/CA tables.

---

## 14. Coverage Summary and Confidence Gaps

### Fully Covered (from source code analysis)

| Entity | Confidence |
|---|---|
| PMProject / Contract (base + extension) | High — full DAC analyzed |
| PMTask | High |
| PMBudget | High — full DAC with all amount fields |
| PMTran | High — full DAC with lineage fields |
| PMRegister | High |
| PMCommitment | High — GUID-based PK, PO linkage confirmed |
| PMAccountGroup | High |
| PMCostCode | High |
| PMChangeOrder | High |
| PMChangeOrderBudget | High |
| PMChangeOrderLine | High |
| PMChangeRequest | High |
| PMProforma | High — AR linkage fields confirmed |
| PMProformaLine | High |
| PMHistory | High — 7-part PK confirmed |
| PMBillingRecord | High |
| PMQuoteTask | High - local SQL definition and DAC summary checked |
| PMAllocation / PMAllocationDetail | High - local SQL definition and DAC summary checked |
| PMProgressWorksheet / PMProgressWorksheetLine | High - local SQL definition and DAC summary checked |
| PMProjectEntity | High - local SQL definition and DAC summary checked |
| ComplianceDocument / ComplianceDocumentBill / ComplianceDocumentReference | High for storage anchors; source-specific behavior requires code verification |
| JointPayee / JointPayeePayment | High for storage anchors; AP/CA settlement requires cross-module verification |
| PJ core documents | High for storage anchors: ProjectIssue, RequestForInformation, DailyFieldReport, DrawingLog, PhotoLog, PJSubmittal |
| Subcontract (projection over POOrder) | High — confirmed as [PXProjection] |

### Partially Inferred (needs deeper analysis for edge cases)

| Area | Gap |
|---|---|
| Retainage fields | Retainage percentage and held amounts are on PMProformaLine and ARTran but exact field names not fully traced |
| Allocation rule internals | PMAllocation rules create PMTran records but the rule engine logic is in graph code, not DAC |
| Billing rule internals | PMBilling rules determine how PMTran amounts become invoice lines; logic is in PMBillingEngine graph code |
| PMForecastDetail | DAC exists but not deeply analyzed — forecast/projection budget feature |
| PMTaskTotal | DAC exists — appears to be an aggregate of task-level totals; may be a summary/projection |
| PMWipAdjustment | Physical storage checked; posting and GL impact still require graph/source verification |
| PMUnbilledDailySummary | Physical table checked; source/update logic requires code verification |
| PMQuote / PMQuote projection | DAC is projection over CRM quote/opportunity data; exact persisted fields require CRM table verification |
| Daily Field Report relation tables | Storage checked at family level; each relation table needs exact target verification for case-specific joins |

### Known Limitations

1. **Column types are inferred** from `[PXDB*]` attributes. Exact SQL Server types may differ slightly.
2. **Index information** cannot be determined from DAC source code.
3. **Customizations** may add fields/tables not present in base code.
4. **Release/posting logic** is in graph code (RegisterReleaseProcess, ProformaEntry, etc.) — not all paths are traced via DAC analysis alone.
5. **Progress billing calculations** involve complex runtime logic in billing engine code that is not fully represented in DAC field descriptions.
6. **Multi-currency conversion** details depend on CurrencyInfo records and rate lookup code.

---

## 15. Appendix

### Glossary

| Term | Definition |
|---|---|
| **DAC** | Data Access Class — Acumatica's ORM entity class mapping to a database table |
| **BQL** | Business Query Language — Acumatica's LINQ-like query language |
| **Graph** | Acumatica's equivalent of a controller/service — contains business logic |
| **Account Group** | A logical grouping of GL accounts for project budget tracking |
| **Cost Code** | A classification code for project costs (used primarily in construction) |
| **Commitment** | A purchase commitment (from PO or subcontract) against the project budget |
| **Pro Forma** | A preliminary invoice document created during project billing, before the final AR invoice |
| **Change Order** | A formal document modifying project budget and/or commitments |
| **Change Request** | A preliminary document that feeds into change orders |
| **Budget Level** | The granularity at which budget lines are tracked (task, task+item, task+cost code, or all) |
| **Non-Project** | A special placeholder project for transactions not associated with any specific project |
| **Extension Table** | A separate physical table that extends a base table, sharing the same PK |
| **Projection** | A BQL-defined view (NOT a physical table) — do not query by DAC name |
| **Project Quote** | Pre-project proposal context; `PMQuote` is a projection, while quote tasks are persisted in `PMQuoteTask` |
| **WIP Adjustment** | Project accounting control document for overbilling/underbilling timing; stored in `PMWipAdjustment*` |
| **Compliance Document** | CN artifact for compliance/lien-waiver/payment-control state, anchored by `ComplianceDocumentID` |
| **Joint Payee** | CN joint-check participant/split tied to AP bill lines and AP payments |
| **PJ Document** | Field/document coordination record such as RFI, issue, daily field report, drawing, photo log, or submittal |
| **Project Files Link** | `PMProjectEntity` relationship between a project and linked documents/entities through NoteID values |

### Module Codes

| Code | Module |
|---|---|
| PM | Project Management |
| CN | Construction |
| PJ | Project Management collaboration |
| GL | General Ledger |
| AR | Accounts Receivable |
| AP | Accounts Payable |
| PO | Purchase Orders |
| SO | Sales Orders |
| IN | Inventory |
| CA | Cash Management |
| EP | Employee Portal / Time & Expenses |
| CR | CRM |
| TX | Tax |
| FA | Fixed Assets |
| DR | Deferred Revenue |
| PR | Payroll |

### Recurring Key-Field Patterns

| Field Name | Meaning | Where Found |
|---|---|---|
| ProjectID / ContractID | Surrogate key for project | PMProject, PMTask, PMBudget, PMTran, PMCommitment, ARTran, APTran, GLTran, SOLine |
| TaskID / ProjectTaskID | Surrogate key for task | PMTask, PMBudget, PMTran, PMCommitment, ARTran, APTran, GLTran |
| AccountGroupID / GroupID | Surrogate key for account group | PMAccountGroup, PMBudget, PMTran, PMCommitment |
| CostCodeID | Surrogate key for cost code | PMCostCode, PMBudget, PMTran, PMCommitment, ARTran, APTran, GLTran |
| InventoryID | Surrogate key for inventory item | InventoryItem, PMBudget, PMTran, PMCommitment, ARTran, APTran, SOLine, POLine |
| CommitmentID | GUID linking PO line to PM commitment | PMCommitment, POLine |
| QuoteID | GUID for CRM/project quote context | CRQuote, PMQuoteTask |
| ComplianceDocumentID | Identity key for compliance documents | ComplianceDocument, ComplianceDocumentBill |
| DailyFieldReportId | Identity key for daily field reports | DailyFieldReport and related DailyFieldReport* tables |
| LinkedDocumentNoteID / LinkedEntityNoteID | NoteID-based project file/entity links | PMProjectEntity |
| NoteID | GUID for attachments/notes | Almost all header tables |
| BranchID | Branch identifier | Most transaction and document tables |
| FinPeriodID | Financial period string | Most transaction tables |

### Screen-to-Table Hints

| Screen ID | Screen Name | Primary Table(s) |
|---|---|---|
| PM301000 | Projects | Contract + PMProject |
| PM302000 | Project Tasks | PMTask |
| PM303000 | Progress Worksheets | PMProgressWorksheet + PMProgressWorksheetLine |
| PM304500 | Project Quotes | PMQuote projection + PMQuoteTask |
| PM304000 | Project Transactions | PMRegister + PMTran |
| PM305600 | WIP Adjustment | PMWipAdjustment + PMWipAdjustmentLine |
| PM306000 | Commitments | PMCommitment (inquiry) |
| PM307000 | Pro Forma Invoices | PMProforma + PMProformaLine |
| PM308000 | Change Orders | PMChangeOrder + PMChangeOrderBudget + PMChangeOrderLine |
| PM308500 | Change Requests | PMChangeRequest |
| PM309000 | Project Budget (Maintenance) | PMBudget |
| PM207500 | Allocation Rules | PMAllocation + PMAllocationDetail |
| PM209000 | External Commitments | PMCommitment |
| PM209500 | Cost Codes | PMCostCode |
| PM201000 | Account Groups | PMAccountGroup |
| CL301000 | Compliance Preferences | Compliance setup tables |
| CL401000 | Compliance Management | ComplianceDocument + related compliance tables |
| CL502000 | Print/Email Lien Waivers | ComplianceDocument / lien waiver processing context |
| PJ301000 | Request for Information | RequestForInformation |
| PJ302000 | Project Issue | ProjectIssue |
| PJ303000 | Drawing Log | DrawingLog + DrawingLogRevision |
| PJ304000 | Daily Field Report | DailyFieldReport + DailyFieldReport* relation/detail tables |
| PJ305000 | Photo Log | PhotoLog + Photo |
| PJ306000 | Submittals | PJSubmittal + PJSubmittalWorkflowItem |
| PO301000 | Purchase Orders | POOrder + POLine |
| SC301000 | Subcontracts | POOrder (Type='RS') + POLine |
| AR301000 | Invoices and Memos | ARRegister + ARInvoice + ARTran |
| AP301000 | Bills and Adjustments | APRegister + APInvoice + APTran |
| GL301000 | Journal Transactions | Batch + GLTran |
