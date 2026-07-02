# Project and Construction Domain Model (PM, CN, PJ) – Extended AI Context

## 1. Purpose and Intended Use

This document is an **AI-oriented domain context** for the **Project Accounting (PM)**, **Construction (CN)**, and **Project Management (PJ)** capabilities of Acumatica ERP.

It is intended to help AI agents prototype:

- New stand-alone features inside the Project and Construction domain
- New cross-domain features that span PM/CN/PJ and adjacent modules
- Extensions that preserve existing business semantics instead of introducing parallel concepts

This document is **not** a technical design specification. It intentionally avoids low-level implementation details, screen-by-screen descriptions, and architectural rules. Those should be supplied separately in technical guidance such as `ARCHITECTURE_RULES.md`.

The goal is to give AI agents a **stable mental model of the business domain** as implemented in Acumatica ERP, while remaining concise enough to be useful as working context.

---

## 2. Scope, Assumptions, and Boundaries

### 2.1 Scope

This document covers:

- The **core project accounting model**: project, task, budget, commitment, actual transaction, billing, change management
- The **construction extension layer**: subcontracts, retainage, compliance, joint payments, progress tracking, project-specific materials, construction reporting
- The **project management collaboration layer**: RFIs, project issues, submittals, drawing logs, photo logs, daily field reports
- The **integration boundary** with adjacent Acumatica domains such as AR, AP, PO, SO, IN, GL, CA, EP, CR, and payroll-adjacent labor scenarios
- The concepts that matter when prototyping both **business features** and **cross-module behavior**

### 2.2 Assumptions

- The document reflects stable business semantics rather than every product switch, localization, or edge-case configuration.
- The document is based on the baseline `BUSINESSMODEL.md` and aligned with publicly documented Acumatica behavior available in **March 2026**.
- The document is optimized for feature reasoning, not for user training or implementation-level reverse engineering.

### 2.3 What This Document Deliberately Does Not Do

This document does not try to be:

- A release-note replacement
- A complete list of screens, fields, statuses, or reports
- A substitute for source code exploration
- A technical contract for persistence, events, APIs, or UX
- A full explanation of accounting, tax, payroll, or inventory valuation internals

---

## 3. How AI Agents Should Use This Context

When an AI agent designs a new feature in this domain, it should reason in the following order:

1. **Identify the real-world event**.
   - What happened in the business?
   - Is it a scope change, cost commitment, actual cost, field issue, billing event, compliance event, or cash event?

2. **Identify the owning domain concept**.
   - Does the event belong primarily to a Project, Task, Budget line, Commitment, Change document, Billing process, Compliance document, or PJ document?

3. **Determine the financial semantic category**.
   - Does the event change:
     - expectation (budget / forecast),
     - obligation (commitment),
     - actual impact (project transaction),
     - invoice candidate / invoice,
     - retainage,
     - compliance eligibility,
     - or cash settlement?

4. **Determine the scope boundary**.
   - Is the feature generic to Projects?
   - Construction-only?
   - Project Management (collaboration) only?
   - Or truly cross-domain?

5. **Preserve existing source-of-truth rules**.
   - Do not move ownership of AR, AP, inventory valuation, or cash into PM/CN/PJ.
   - Do not create parallel financial concepts when existing ones already exist.

6. **Preserve traceability and auditability**.
   - A user must be able to understand how a field event, vendor document, or approved change impacted budgets, commitments, billing, and financial statements.

7. **Prefer extension over duplication**.
   - Extend an existing aggregate or lifecycle if the business meaning is already present.
   - Introduce a new concept only when the business domain truly requires a new concept.

Use this document to decide what additional context to request, not to replace that context:

- If the question depends on exact DAC fields, relationships, exposed API/OData/GI shape, or screen-level reference behavior, inspect local source, local definitions, and linked Wiki documentation, then verify against the current branch when branch-specific behavior matters.
- If the question depends on current requirements, acceptance criteria, or customer-facing intent, use Jira and linked Wiki specifications.
- If the question depends on tenant data, upgrade history, actual balances, document chains, or environment version, use read-only SQL and system diagnostics.
- If the question depends on implementation mechanics, lifecycle hooks, workflow, persistence, or tests, use the local source and the architecture/refactoring docs.

---

## 4. High-Level Domain Map

The Project and Construction domain in Acumatica is best understood as a stack of cooperating layers.

| Layer | Business Role | Typical Concepts | Notes |
|---|---|---|---|
| **Pre-Project Commercial Layer** | Proposal and conversion context before the project becomes execution truth | Project Quote, Opportunity context, Template-derived proposal | Can seed a project but is not itself the approved project ledger |
| **Project Accounting (PM) Core** | Financial and operational control of projects | Project, Task, Budget, Account Group, Transaction, Commitment, Billing, Change Order | The stable project-centric backbone |
| **Forecasting and Control Layer** | Predict expected outcomes and manage profitability | Budget Forecast, Cost Projection, Revised Budget, Exposure | Sits between baseline planning and actual performance |
| **Construction Commercial Layer (CN)** | Construction-specific execution and contract control | Subcontract, Retainage, Compliance, Joint Payment, Progress Worksheet, AIA reporting | Extends PM without replacing it |
| **Project Management Collaboration Layer (PJ)** | Site and document coordination | RFI, Project Issue, Daily Field Report, Drawing Log, Photo Log, Submittal, Project Files | Operational context and collaboration, not the financial ledger |
| **Adjacent ERP Domains** | Source or consumer of project impact | AR, AP, PO, SO, IN, GL, CA, EP, CR, payroll-adjacent labor processes | PM/CN/PJ orchestrate project context across them |

A useful mental model is:

**Project = business boundary**

Inside that boundary, Acumatica tracks:

- what was planned,
- what is currently obligated,
- what has actually happened,
- what can be billed,
- what has been invoiced,
- what remains withheld through retainage,
- what may happen next through forecasts and pending changes,
- and what field/compliance events influence those outcomes.

---

## 5. Ubiquitous Language: Real World to Acumatica Mapping

This section is intentionally explicit because AI agents often receive business requests in real-world language rather than product terminology.

| Real-World Concept | Acumatica Concept | Meaning in This Domain |
|---|---|---|
| Job, project, contract, engagement | **Project** | The primary financial and operational boundary |
| Proposal, bid, quote before project creation | **Project Quote** | Commercial pre-project artifact that may convert into a project |
| Phase, work package, location, WBS segment | **Project Task** | A subdivision used for control, execution, and billing |
| Cost category, revenue category | **Account Group** | Financial classification used for budgets and transactions |
| Construction cost breakdown code, CSI-like code | **Cost Code** | Construction-specific detail dimension |
| Material / labor / service line | **Inventory Item / Labor Item / Resource** | What is consumed, billed, or analyzed |
| Workers compensation, union, certified-labor classification | **Work Code / Union / Labor classification** | Payroll-adjacent project labor classification, not a replacement for task or account group |
| Planned contract amount or planned cost | **Budget / Budget Line** | Expected cost or revenue |
| Awarded vendor work not yet invoiced | **Commitment / Subcontract** | Future obligation |
| Vendor invoice / actual resource usage | **Project Transaction** (from AP, IN, EP, etc.) | Realized cost or revenue impact |
| Internal redistribution or WIP timing adjustment | **Allocation / WIP Adjustment** | Derived accounting/control layer over project transactions, not a new source document |
| Customer billing package | **Project Billing / Pro Forma / AR Invoice** | Monetization of project work |
| Proposed scope change | **Change Request** | Potential change under evaluation |
| Approved commercial/scope change | **Change Order** | Authorized change that affects the project financially |
| Projected final cost / expected overrun | **Cost Projection / Budget Forecast** | Forward-looking view of outcome |
| Amount intentionally withheld | **Retainage** | Deferred settlement on customer or vendor side |
| Vendor qualification or payment-control document | **Compliance Document** | Eligibility and risk control artifact |
| Shared payment to main vendor and another payee | **Joint Payment / Joint Check** | Controlled settlement mechanism |
| Question to architect/engineer | **RFI** | Formal request for clarification |
| Site problem, defect, coordination issue | **Project Issue** | Operational problem record |
| Daily site diary | **Daily Field Report** | Site activity and evidence record |
| Drawing register | **Drawing Log** | Technical revision/document tracking |
| Photo evidence | **Photo Log** | Visual project documentation |
| Formal submitted package for review/approval | **Submittal** | Controlled submission workflow |
| Shared project document packet | **Project Files** | Linked evidence and document organization across project entities |
| Project-specific stock on hand | **Project Inventory Tracking** | Material attributed to a project rather than free stock |

AI agents should translate business requests into these concepts before proposing features.

---

## 6. Core Domain Structure

### 6.1 Primary Domain Principle

The **Project** is the central aggregate boundary for project-centric business meaning.

Many adjacent modules create source documents, but when those documents become project-relevant, they are interpreted through the project model:

`Project -> Task -> Budget / Commitment / Transaction / Billing / Change / Forecast / Construction Controls`

This does **not** mean every entity is physically stored under Project. It means the Project is the primary semantic anchor for:

- financial attribution,
- operational grouping,
- budgetary control,
- billing logic,
- change history,
- construction-specific extensions,
- and reporting of project performance.

### 6.2 Supporting Configuration vs Business Transactions

Some objects exist mainly to provide defaults, policy, or organization:

- **Project Template**: a reusable definition for new projects
- **Project Group**: organizational and access-control grouping
- **Project Management Class**: defaults for PJ documents and workflows
- **Rate Table**: reusable pricing parameters
- **Billing Rule / Allocation Rule**: policy definitions for monetization and redistribution

These matter a lot for feature design, but they are not the same as business transactions such as commitments, actuals, invoices, or change documents.

### 6.3 Pre-Project Commercial Context

A project may be preceded by a **Project Quote** or opportunity-driven proposal. This layer can carry customer, template, task, price, tax, shipping, and project-manager context before the project is created or activated.

The important distinction is:

- **Project Quote** = proposed commercial/project structure
- **Project** = execution and financial control boundary
- **Budget / Billing / Transactions** = project accounting truth after the project exists

AI agents should not treat a quote as an approved project budget, actual cost, commitment, or AR document. When a feature starts before project creation, check whether the correct owner is CRM/opportunity, Project Quote, Project Template, or the Project itself.

---

## 7. Core Business Concepts

### 7.1 Project

A **Project** represents a contractual, internal, or operational endeavor for which Acumatica accumulates cost, revenue, obligations, and execution context.

#### What a Project Defines

A Project commonly defines or influences:

- the customer or business relationship context
- project currencies and financial context
- budget structure and granularity
- billing behavior and defaults
- retainage-related behavior on the customer side
- project-specific inventory behavior when used
- visibility, grouping, and access boundaries
- the framework within which tasks, budgets, commitments, actuals, and change documents exist

#### What a Project Is Not

A Project is **not**:

- the owner of cash balances
- the master record for vendors, customers, or items
- the inventory valuation ledger
- the final financial ledger

Those remain owned by adjacent domains such as AR, AP, IN, GL, and CA.

#### AI Design Guidance

If a feature changes how work is grouped, budgeted, tracked, billed, forecasted, or compliance-controlled for a job, it probably belongs at the Project level or is at least anchored to Project.

If a feature is about vendor identity, AR document aging, inventory costing, or cash settlement, Project usually provides context but not ownership.

---

### 7.2 Project Group, Project Template, and Management Classes

These concepts are important because AI agents often mistake them for transactional business objects.

#### Project Group

Used for:

- organizing projects at scale
- segmentation by business unit or practice
- row-level security or visibility boundaries

#### Project Template

Used for:

- creating projects with predefined defaults
- standardizing common tasks, billing setup, budget structure, and policies
- enabling faster onboarding of repetitive project types

#### Project Management Class

Used mainly in the PJ collaboration layer for:

- setting defaults for RFIs, project issues, and other construction project management documents
- standardizing response windows, priorities, and document behavior

#### AI Design Guidance

Do not put transactional state into templates or classes. These are policy/defaulting constructs, not event records.

---

### 7.3 Project Task

A **Project Task** is the primary subdivision of a Project for control and execution.

A task may correspond to:

- a phase,
- a discipline,
- a work package,
- a location,
- a customer-facing deliverable,
- or another meaningful segment of project execution.

#### Why Tasks Matter

Tasks are often the level at which Acumatica differentiates:

- budgets
- billing rules
- allocation rules
- rate tables
- dates or execution windows
- billable vs non-billable behavior
- visibility of progress and performance

#### Typical Relationships

A Project Task is linked to:

- budget lines
- commitments
- actual project transactions
- billing configuration and invoice generation
- changes and forecasts
- construction project management documents
- project inventory usage or material assignment

#### AI Design Guidance

If a feature requires segmentation by phase or work package, use Task unless the business meaning actually belongs at budget-line detail.

Do not create custom pseudo-task concepts when existing task semantics are sufficient.

---

### 7.4 Classification Dimensions

Project and Construction tracking relies on several interacting dimensions.

#### Account Group

**Account Group** provides the financial meaning of project amounts.

It is used to:

- classify budget lines and actuals as cost, revenue, asset, liability, etc.
- organize project reporting
- bridge project semantics to GL account ranges
- support billing and allocation logic

In practice, Account Group answers the question:

**"What type of money is this in project terms?"**

#### Cost Code

**Cost Code** provides construction-oriented cost detail.

It is used to:

- represent standard construction cost breakdown structures
- provide more granular project control than account groups alone
- track costs and budgets in a way meaningful to estimators, PMs, and superintendents

Cost Code answers the question:

**"Which detailed construction bucket does this work belong to?"**

#### Inventory Item / Labor Item / Resource

These dimensions answer the question:

**"What exactly was consumed, provided, or billed?"**

They may represent:

- material items
- service items
- labor items
- employee work
- equipment-related usage
- billable or cost-bearing resources

#### Labor and Work Classification

Project labor may carry payroll-adjacent classifications such as work code, union, certified-labor, or workers compensation context. These classifications help determine labor rules, eligibility, reporting, or cost/rate behavior.

They do not replace:

- Task as the project execution segment
- Account Group as the financial meaning
- Cost Code as the construction cost breakdown
- Labor Item / Resource as the consumed or billed thing

#### AI Design Guidance

When a new feature needs more granularity, first determine whether the need is already covered by:

- Task (where in the project)
- Account Group (financial meaning)
- Cost Code (construction detail)
- Inventory/Labor/Resource dimension (what was used)
- Labor/work classification (payroll-adjacent rule context)

A new business concept should not be introduced just because one of these dimensions was overlooked.

---

### 7.5 Budget and Budget Lines

A **Budget** represents planned cost and planned revenue. It is the core expression of expectation in the project domain.

#### Budget as Control Envelope

Budget lines can act as:

- the initial plan,
- the revised authorized plan,
- the reference for progress billing,
- the basis for cost control,
- the comparison point for actuals, commitments, and forecasts.

#### Budget Level and Key Structure

A project defines a **budget level**, which determines the granularity of budget records. Common combinations include:

- Project + Task + Account Group
- Project + Task + Account Group + Inventory Item
- Project + Task + Account Group + Cost Code
- Project + Task + Account Group + Inventory Item + Cost Code

#### Budget Values That Matter

A budget line can participate in multiple financial views, including:

- original budget
- revised budget
- committed amounts
- actual amounts
- pending or draft change impact
- forecasted outcomes

#### Cost Budget vs Revenue Budget

A single project can contain both:

- **Cost Budget** lines: what the project is expected to consume
- **Revenue Budget** lines: what the project is expected to earn or bill

These are related but not interchangeable.

#### AI Design Guidance

A budget is not merely an estimate spreadsheet. In Acumatica it is a control and reporting structure.

A feature that changes expected project outcome must decide whether it belongs in:

- the baseline or revised budget,
- a pending change,
- or a forecast/projection revision.

That distinction is critical.

---

### 7.6 Commitments

A **Commitment** represents a future obligation that has not yet fully become actual cost.

#### Typical Sources of Commitments

- Purchase Orders
- Subcontracts
- External commitments entered for tracking purposes

#### Business Meaning

Commitments answer the question:

**"What cost exposure has the project already committed to, even if the final vendor billing has not yet been posted?"**

#### Commitment Lifecycle Semantics

A commitment may move through states such as:

- planned or draft
- open/active
- partially received or partially billed
- fully invoiced or completed
- closed

Exact status names can vary by document type, but this semantic progression is stable.

#### Why Commitments Matter

They:

- update committed budget amounts
- provide forward visibility into cost exposure
- support procurement and subcontract control
- participate in change management
- allow PMs to compare expected, committed, actual, and forecasted values

#### AI Design Guidance

A commitment is **not** actual cost.

If a feature creates obligation before realization, it probably affects commitments.
If it records realized cost, it belongs in actual transactions instead.

---

### 7.7 Subcontracts

A **Subcontract** is a construction-specific commitment with stronger commercial and compliance meaning than a generic purchase commitment.

#### Distinguishing Characteristics

Compared with ordinary purchasing commitments, subcontracts are typically associated with:

- a subcontractor providing project work or services
- retainage logic
- compliance requirements
- change handling specific to awarded work
- construction reporting and settlement needs

#### Why It Matters

A subcontract is not just "another PO." It is a commercial artifact in the construction layer that carries project, vendor, compliance, and retainage semantics at once.

#### AI Design Guidance

If a feature concerns awarded outside work, subcontract change handling, compliance-gated payment, or vendor-side construction progress, it likely belongs to the subcontract model rather than generic PO only.

---

### 7.8 Actuals and Project Transactions

A **Project Transaction** represents the actual realized financial or operational impact attributed to a project.

#### Typical Sources of Actuals

Actuals may originate from released or processed source documents in adjacent modules such as:

- AP vendor bills
- AR invoices or revenue-related documents
- SO-related billable activity
- Inventory issues and material movements
- employee time and expenses
- direct GL-originated project postings where allowed
- other project-aware operational flows

#### Business Meaning

Project transactions answer the question:

**"What has actually happened to the project?"**

They are the core basis for:

- actual cost and revenue reporting
- variance analysis
- time and material billing
- downstream profitability analysis

#### Important Distinction

- **Budget** = expectation
- **Commitment** = obligation
- **Transaction** = actual realized impact

#### AI Design Guidance

Do not invent a parallel financial "actuals" concept if project transactions already provide the correct semantic model.

If data is derived from source documents but affects project actuals, the feature must preserve traceability back to the source document.

---

### 7.9 Billing and Monetization

Billing is the mechanism by which project data becomes customer-facing invoicing.

#### Billing Is a Policy Layer, Not Just a Final Document

Billing in Acumatica involves multiple policy concepts:

- **Billing Rules**: define how billable amounts are generated
- **Billing Steps**: sequence of calculation logic
- **Rate Tables**: parameterized pricing logic
- **Allocation Rules**: redistribution and billable accumulation logic
- **Markups / Premiums**: commercial uplift over cost or effort
- **Invoice Grouping and Pro Forma Behavior**: packaging and approval semantics

#### Rate Selection and Allocation

Rates are selected during billing or allocation from the combination of project transaction context, the rate type used by the billing/allocation step, and the rate table assigned through the project/task setup.

This means rate-sensitive features must preserve:

- the difference between cost amount, billable quantity, and billed amount
- the policy role of billing rules and allocation rules
- the fallback behavior when no rate is found
- the trace from source project transaction to derived billing or allocation result

Allocation rules can create derived project transactions or redistribute project cost meaning. They should not be confused with the original operational source of the cost.

#### WIP, Unbilled, and Timing Review

Some project accounting flows track work in process, unbilled amounts, or overbilling/underbilling timing. These concepts help reconcile when work is earned, billed, recognized, or adjusted.

AI agents should treat WIP and unbilled review as an accounting/control layer over project activity, not as a separate actuals ledger and not as a substitute for AR, GL, or PMTran source flows.

#### Common Billing Modes

Common project billing patterns include:

- **Time and Material**: bill from actual billable transactions
- **Progress Billing**: bill according to recorded progress against budget or quantities
- **Cost Plus**: bill cost with markup logic
- **Fixed Fee / Scheduled Billing**: bill predefined amounts or schedules

#### Pro Forma as Intermediate Commercial Review

In many scenarios, **Pro Forma** is the review layer between project billing logic and AR.

It allows:

- review before AR document creation
- adjustment and write-off decisions
- retainage-aware invoice preparation
- construction-specific reporting such as AIA output

#### Progress Tracking and Progress Worksheets

In construction scenarios, progress-related billing may involve explicit progress capture mechanisms and worksheets that separate progress recognition from final invoice creation.

#### AI Design Guidance

A feature that changes pricing, markups, invoice grouping, or billable accumulation likely belongs in billing policy, not in actual transaction creation.

A feature that changes commercial review or invoice packaging likely belongs near Pro Forma, not inside AR core.

A feature that changes WIP, allocation, or unbilled timing should preserve the distinction between original source transactions, derived project accounting entries, and final GL/AR ownership.

---

### 7.10 Change Management

Change management is the controlled mechanism for modifying project scope, financial expectations, and commitments.

#### Two-Tier Change Semantics

Acumatica distinguishes between:

#### Change Request

A **Change Request** represents a proposed change.
It is used when the project team needs to:

- capture scope that may change
- estimate cost and revenue impact
- propose markups or pricing
- identify schedule impact
- prepare vendor-side or commitment-side consequences
- maintain a pre-approval audit trail

#### Change Order

A **Change Order** represents an approved and commercially or operationally authorized change.
It is used to:

- finalize budget changes
- apply approved cost and/or revenue adjustments
- update commitments or create commitment changes
- provide auditable control of project scope evolution

#### Why This Distinction Matters

Not every proposed change should immediately revise the project’s authorized budget.

The model intentionally separates:

- **potential impact** from
- **approved impact**

#### AI Design Guidance

If a feature captures possible future scope impact, it belongs closer to Change Request.
If it formalizes approved effect on budget, commitments, and billing, it belongs closer to Change Order.

Avoid modeling approved scope impact as an uncontrolled manual budget edit.

---

### 7.11 Forecasting, Budget Forecasts, and Cost Projections

A mature project domain needs more than plan vs actual. It also needs a structured model of expected final outcome.

#### Why Forecasting Exists

Projects frequently need to answer:

- What is the expected final cost?
- What is the expected final revenue?
- What cost remains to complete?
- Which budget lines are trending toward overrun?
- What is the expected margin if current commitments and trends continue?

#### Forecasting Concepts

The forecasting layer may include concepts such as:

- budget forecast revisions
- cost projection revisions
- expected final values
- cost-to-complete assumptions
- forecasted exposure beyond current commitments

#### Relationship to Other Concepts

Forecasts are **not** the same as:

- baseline budgets,
- approved change orders,
- or actual transactions.

Instead, forecasts synthesize:

- current budget,
- pending changes,
- commitments,
- actuals,
- and human assumptions about remaining work.

#### AI Design Guidance

If a feature is predictive, analytic, trend-based, or scenario-driven, it should probably extend the forecast/projection model rather than overwrite budget or actuals.

This is especially important for AI-assisted forecasting and profitability features.

---

### 7.12 Project Inventory and Material Control

Projects in Acumatica may have project-specific material behavior rather than relying only on generic free stock.

#### Why This Matters

In many construction and field scenarios, the business needs to know not only that material exists in inventory, but also:

- whether it has been purchased for a particular project,
- whether it is on site or reserved for the project,
- whether quantity only or both quantity and cost must be tracked by project,
- how issues, transfers, returns, and usage affect project visibility.

#### Business Role

Project inventory tracking helps bridge:

- procurement,
- warehouse and site material handling,
- project cost attribution,
- and field execution.

#### AI Design Guidance

If a feature concerns project-specific stock reservation, site material visibility, transfer, return, or consumption tracking, it should build on project inventory concepts rather than introducing a separate parallel material ledger.

---

### 7.13 Retainage

**Retainage** is a withholding mechanism used to defer part of settlement while work progresses or until contractual conditions are satisfied.

#### Key Semantics

Retainage may exist on:

- the **customer side** (amount withheld from project billing)
- the **vendor side** (amount withheld from subcontractor or vendor settlement)

#### What Retainage Does and Does Not Mean

Retainage:

- changes the timing of settlement
- affects cash flow and receivable/payable timing
- may require separate release events
- may appear in construction billing and reporting artifacts

Retainage does **not** by itself change:

- the total contract amount,
- the underlying earned amount,
- or the actual cost incurred.

#### AI Design Guidance

A feature that touches project billing, subcontract settlement, AIA reports, or payment control must explicitly consider retainage.

Ignoring retainage in construction features often leads to incomplete designs.

---

### 7.14 Compliance Management

**Compliance Management** is the control layer that determines whether project participants or payments satisfy required documentation and risk controls.

#### Typical Compliance Artifacts

Examples include:

- lien waivers
- insurance certificates
- bonds
- permits
- certifications
- other required vendor or project compliance documents

#### Why Compliance Matters

Compliance can affect whether the business is allowed to:

- award work,
- proceed with a subcontract,
- release payment,
- or continue certain controlled processes.

#### Cross-Domain Nature

Compliance is not isolated. It interacts with:

- Project
- Vendor
- Subcontract / Commitment
- AP bills and payments
- joint payments
- construction controls

#### AI Design Guidance

Compliance is a **gate** and a **risk-control mechanism**, not a cost object.

When designing payment, subcontract, or vendor workflows in construction, assume compliance may block or qualify the action.

---

### 7.15 Joint Payments / Joint Checks

A **Joint Payment** is a controlled settlement pattern in which payment is directed to the main vendor and another related payee.

#### Business Purpose

It is commonly used when the paying organization wants control over how payment reaches downstream parties such as suppliers or subcontractors.

#### Why It Matters

It sits at the intersection of:

- AP settlement,
- vendor risk control,
- compliance,
- and construction-specific payment practice.

#### AI Design Guidance

If a feature changes vendor-side settlement or lien-waiver-sensitive payment flow, joint payment behavior may need to be considered explicitly.

---

### 7.16 Construction Project Management Documents (PJ)

PJ documents capture collaborative and operational project reality.

They are extremely important for AI prototyping because many useful features start from field events rather than from financial documents.

#### Request for Information (RFI)

An **RFI** captures a formal request for clarification, usually directed to a responsible party such as a design or engineering stakeholder.

Use cases:

- clarify ambiguity in drawings or scope
- track due dates and responses
- maintain communication traceability
- connect operational uncertainty to later scope/cost changes

#### Project Issue

A **Project Issue** captures a problem, defect, coordination blocker, or other field/site concern.

Use cases:

- issue tracking
- responsibility assignment
- lifecycle and resolution management
- potential conversion to RFI or Change Request

#### Daily Field Report

A **Daily Field Report** is the daily project-site operational log.
It may include:

- weather
- labor activity
- equipment usage
- subcontractor activity
- visitors, notes, and observations
- photos and supporting evidence

It is critical because it provides high-context operational evidence that may later support claims, billing context, disputes, productivity analysis, or change justification.

#### Drawing Log

A **Drawing Log** tracks drawings, revisions, and related coordination context.

#### Photo Log

A **Photo Log** captures visual evidence and progress context tied to the project.

#### Submittal

A **Submittal** tracks packages submitted for review, approval, and coordination.

#### Project Files and Linked Evidence

**Project Files** organize documents and evidence around project entities. They are not a separate business transaction, but they can preserve context for RFIs, issues, drawings, photos, submittals, change discussions, and field reports.

For AI reasoning, project files matter when a feature depends on:

- document traceability
- evidence attached to a project event
- navigation between project entities and their supporting files
- AI-assisted extraction or classification of project documents

#### Key Role of PJ in the Overall Domain

PJ is not the financial ledger. Instead, it provides:

- project communication structure
- issue and document workflows
- evidence, files, and coordination context
- triggers for change and risk identification

#### AI Design Guidance

If a feature starts from a field observation, document workflow, response SLA, or operational issue, PJ is often the correct starting point.

If the feature creates or changes financial effect, PJ usually supplies the trigger or evidence, while PM/CN own the financial consequence.

---

### 7.17 Actors and Business Roles

The domain is easier to reason about when tied to actors.

Common roles include:

- **Project Manager**: owns project execution and outcome
- **Project Accountant**: owns budget control, billing, and financial project correctness
- **Estimator / Preconstruction Lead**: influences budgets, cost structure, and change assumptions
- **Buyer / Procurement Role**: creates commitments and purchasing documents
- **AP Clerk / AP Specialist**: enters vendor bills and participates in payment flow
- **AR / Billing Specialist**: reviews pro forma and customer invoicing
- **Superintendent / Foreman / Site Lead**: creates field reports, issues, and operational evidence
- **Compliance Manager**: controls document completeness and payment gates
- **Controller / Finance Lead**: cares about GL integrity and financial outcome
- **Customer Representative**: external participant in billing and change acceptance
- **Architect / Engineer / External Reviewer**: may respond to RFIs, submittals, and issue workflows

AI agents should infer which role is the primary actor of a proposed feature, because that often reveals the correct aggregate and workflow.

---

## 8. Lifecycle and State Models

Exact status names vary across forms and features, but the following lifecycle models capture the stable business semantics.

### 8.1 Project Lifecycle

Typical conceptual lifecycle:

1. **Template / Setup**
2. **Planning / Pre-Execution**
3. **Active Execution**
4. **Billing and Settlement in Progress**
5. **Substantial Completion / Operational Completion**
6. **Closed / Archived**

During the lifecycle, the project accumulates:

- setup policies,
- budgets,
- commitments,
- actuals,
- billing history,
- retainage,
- compliance context,
- and project management records.

### 8.2 Task Lifecycle

Typical conceptual lifecycle:

1. planned
2. active/open
3. completed
4. canceled or closed

Tasks are important because many downstream documents become invalid or restricted when a task is no longer open for activity.

### 8.3 Budget Lifecycle

A budget usually evolves through these conceptual stages:

1. **Initial baseline / original budget**
2. **Revised budget through controlled changes**
3. **Consumption by commitments and actuals**
4. **Comparison against forecasts and profitability views**
5. **Historical closed-state reporting**

### 8.4 Commitment Lifecycle

A typical commitment or subcontract lifecycle is:

1. draft / created
2. approved / active
3. partially consumed through receipts, bills, or progress
4. completed / fully billed
5. closed

### 8.5 Actual Transaction Lifecycle

A simplified actuals lifecycle is:

1. source document entered
2. source document released/processed
3. project transaction updates actuals and becomes eligible for reporting and possibly billing
4. later correction handled through adjustment, reversal, or related correction flow

### 8.6 Billing Lifecycle

A simplified billing lifecycle is:

1. billable basis exists (transactions, progress, fixed schedule, etc.)
2. billing process evaluates rules
3. pro forma or intermediate review document prepared if used
4. AR invoice created/released
5. retainage may remain outstanding until separate release
6. cash collection handled by AR/CA

### 8.7 Change Lifecycle

Typical change sequence:

1. issue / request / idea is identified
2. change request captures potential impact
3. approval or rejection occurs
4. approved impact is formalized as change order
5. project budgets / commitments / billing posture are updated
6. historical trail remains visible

### 8.8 PJ Document Lifecycle

PJ documents usually follow some version of:

1. created
2. assigned / in review
3. responded / approved / converted, depending on type
4. closed

Important conversion paths may include:

- Issue -> RFI
- Issue -> Change Request
- RFI -> Change Request

### 8.9 Compliance Lifecycle

A compliance artifact typically moves through:

1. required
2. requested / pending
3. received
4. valid / approved
5. expiring or expired
6. blocking or warning state depending on policy

### 8.10 Forecast Lifecycle

A forecast or projection revision typically moves through:

1. revision created
2. assumptions entered or recalculated
3. compared against budget, commitments, and actuals
4. revised over time as project knowledge improves
5. superseded by a newer revision

---

## 9. Domain Invariants and Source-of-Truth Rules

The following invariants are the most important rules for AI agents to preserve.

1. **The Project is the primary financial and operational boundary.**
   Every meaningful cost, revenue, commitment, billing event, change, forecast, or construction control must be attributable to a project when it belongs to this domain.

2. **A Project Task belongs to exactly one Project.**
   Tasks segment the project; they do not float across projects.

3. **Budget granularity is controlled by the project’s budget structure.**
   A feature must respect existing budget-level dimensions before introducing new line semantics.

4. **Account Group determines financial meaning.**
   Cost Code adds construction detail; it does not replace the financial role of Account Group.

5. **Commitments represent obligations, not actual cost.**
   A PO or subcontract can create cost exposure without yet creating realized project actuals.

6. **Actual project cost and revenue come from released operational or financial source flows.**
   PM reflects project impact; it does not replace the source module as owner of the source document.

7. **Billing monetizes project work; it does not create project actual cost.**
   Billing consumes budget progress, billable actuals, or policy-defined commercial basis.

8. **Change Requests and Change Orders are not interchangeable.**
   Potential scope impact must remain distinguishable from approved scope impact.

9. **Retainage changes timing of settlement, not the underlying earned or incurred amount.**

10. **Compliance can block payment or progression without changing the underlying commitment or actual.**
    Eligibility and monetary truth are related but not identical.

11. **PJ documents are operational truth, not financial truth.**
    An issue, RFI, or daily field report may justify a change or explain a cost, but it is not itself a budget or a GL-posting object.

12. **AR owns customer receivable documents; AP owns vendor payable documents; CA owns cash movement; GL owns the final ledger.**
    PM/CN/PJ must integrate with these domains without stealing their ownership.

13. **Inventory valuation remains an inventory responsibility even when stock is tracked by project.**
    The project model adds attribution and visibility, not a separate valuation universe.

14. **Forecasts model expected future outcome and must remain distinguishable from current approved budget and posted actuals.**

15. **Every cross-domain feature must preserve auditability.**
    A user should be able to trace impact from source event -> project meaning -> invoice/payment/reporting consequence.

16. **A Project Quote is not the same as an active Project.**
    It may seed setup, pricing, task structure, or conversion decisions, but it is not approved project accounting truth until converted into the appropriate project structures.

17. **Rates, allocations, WIP, and unbilled summaries are derived project-accounting layers.**
    They can change billing or accounting timing and presentation, but they must remain traceable to source project transactions and final AR/GL ownership.

18. **Project Files and attachments are evidence and organization, not independent financial state.**
    They can explain, support, or classify project events, but they do not replace PJ documents, change documents, transactions, or source invoices.

---

## 10. Core Business Flows

### 10.1 Project Setup and Baseline Flow

Typical sequence:

`Opportunity / Project Quote (optional) -> Template / Setup -> Project -> Tasks -> Budget Structure -> Initial Budgets -> Billing Policies -> Ready for Execution`

This is where the system establishes:

- how the project will be tracked,
- at what granularity,
- and by what monetization rules.

### 10.2 Procurement and Commitment Flow

Typical sequence:

`Need for work or material -> PO / Subcontract / External Commitment -> Committed Budget Exposure -> Later Receipt/Bill/Completion`

This is the domain flow for future cost exposure.

### 10.3 Cost Actualization Flow

Typical sequence:

`Source operational/financial document -> Release / Processing -> Project Transaction -> Actual Budget Impact -> Profitability Reporting`

This is the transition from obligation or activity to actual realized impact.

### 10.4 Labor and Expense Flow

Typical sequence:

`Employee time / expense / labor activity -> Project attribution -> Actual cost -> Optional billable basis -> Billing`

In some scenarios, labor rates and billable rates are distinct, and labor may interact with payroll-adjacent requirements.

### 10.5 Material and Project Inventory Flow

Typical sequence:

`Project-specific procurement or stock reservation -> Project inventory visibility -> Issue / transfer / return / usage -> Project cost impact`

This flow is important when project materials must remain separate from general stock from an operational perspective.

### 10.6 Revenue and Billing Flow

Typical sequence:

`Project work / billable actuals / progress -> Billing Rule Evaluation -> Pro Forma (optional) -> AR Invoice -> Retainage / Collection`

This is the monetization flow.

### 10.7 Progress Billing Flow

Typical sequence:

`Revenue budget / quantities -> Progress capture -> Amount eligible to bill -> Pro Forma / AR -> AIA or construction reporting if applicable`

This is especially important in construction and fixed-scope project billing.

### 10.8 Change Flow

Typical sequence:

`Issue / customer request / field discovery -> Change Request -> Approval -> Change Order -> Budget / Commitment / Billing Update`

This is the controlled path from uncertain change to authorized project impact.

### 10.9 Forecasting and Control Flow

Typical sequence:

`Budget + Commitments + Actuals + Known trends -> Forecast Revision / Cost Projection -> Expected Final Outcome -> Management Action`

This is the management-control loop, not a transactional posting loop.

### 10.10 Field-to-Finance Flow

Typical sequence:

`Daily Field Report / Issue / RFI / Submittal -> Operational decision or risk visibility -> Change / Cost / Billing / Compliance consequence`

This flow is crucial for AI features because many modern product ideas start in the field and only later affect finance.

### 10.11 Compliance and Controlled Payment Flow

Typical sequence:

`Commitment / Bill / Payment candidate -> Compliance validation -> Joint payment or ordinary payment -> Settlement`

This flow sits at the intersection of construction risk control and AP settlement.

### 10.12 Rate, Allocation, and WIP Flow

Typical sequence:

`Project Transaction / billable basis -> Rate selection -> Billing or Allocation rule -> Derived project accounting result -> Pro Forma / WIP review / GL or AR consequence`

This flow is a derived control layer. It must preserve the distinction between source activity, calculated project accounting result, and final financial ownership.

---

## 11. Cross-Module Integration and Ownership Matrix

The Project and Construction domain is powerful precisely because it **does not exist in isolation**.
It orchestrates project context across multiple ERP domains.

### 11.1 Integration Matrix

| Adjacent Module | What the Adjacent Module Owns | How PM/CN/PJ Interact |
|---|---|---|
| **AR** | Customer invoices, receivables, customer settlement, retainage receivable settlement | PM billing produces invoice candidates and often creates AR invoices; CN adds construction billing and retainage semantics |
| **AP** | Vendor bills, payables, vendor settlement, retainage payable settlement | Project costs become actuals through AP-aware flows; CN adds compliance and joint payment considerations |
| **PO** | Purchasing documents and procurement commitments | PM consumes PO-derived commitments; CN adds subcontract semantics and construction commitment behavior |
| **SO** | Sales-order-related customer demand and commercial source data | Project work may be linked to customer order context or rebill scenarios |
| **IN** | Inventory items, stock movement, inventory valuation | Projects may track stock by project; PM/CN consume material movements for project visibility and cost attribution |
| **GL** | Final ledger posting and chart-of-accounts ownership | Account Groups bridge project semantics to GL; PM does not replace GL |
| **CA** | Cash accounts, payments, cash movement | Project billing and payables affect cash indirectly through AR/AP/CA settlement |
| **EP** | Time and expense capture, employee activity input | Project labor and expense actuals may originate here and later participate in billing |
| **CR** | Business accounts, contacts, activities, relationship context | Projects, customers, vendors, and PJ communication often depend on shared relationship data |
| **Payroll / Labor-Adjacent Scenarios** | Earnings, deductions, labor regulation outputs, certified-project-specific labor handling where applicable | Project attribution, labor rates, certified labor requirements, and labor cost semantics may intersect here |

### 11.2 Source-of-Truth Matrix

This table is especially important for AI agents.

| Business Question | Primary Source of Truth |
|---|---|
| What work/cost/revenue did we plan? | **Project Budget** |
| What proposal may become a project? | **Project Quote / CRM opportunity context** |
| What do we currently expect the final outcome to be? | **Forecast / Cost Projection / Budget Forecast** |
| What cost have we already committed to? | **Commitments / Subcontracts / Purchasing obligations** |
| What has actually happened to the project? | **Released Project Transactions sourced from operational/financial modules** |
| Which rate or allocation policy derived this amount? | **Billing Rule / Allocation Rule / Rate Table + source transaction context** |
| What can we bill now? | **Billing process + billable basis + progress state** |
| What is work-in-process or unbilled timing telling us? | **WIP / unbilled project accounting review, traceable to source transactions and GL/AR outcome** |
| What has already been invoiced to the customer? | **AR documents produced by billing** |
| What amount is being withheld? | **Retainage state in customer/vendor billing and settlement flows** |
| What cash has moved? | **AR/AP/CA settlement** |
| Which vendor or payment is blocked or controlled? | **Compliance + AP/payment workflow** |
| What field event explains or initiated the change? | **PJ documents such as Issue, RFI, Daily Field Report, Submittal** |
| Which files or evidence support the project event? | **Project Files / attached documents linked to project entities** |

### 11.3 Integration Principle

PM/CN/PJ provide **project semantics and coordination**.
They do not replace the surrounding ERP modules.

The correct design posture for AI features is therefore:

- enrich project behavior,
- preserve ownership boundaries,
- and connect the modules through traceable, auditable flows.

---

## 12. Variation Points and Edition Boundaries

Not every project feature belongs to the same layer.

### 12.1 Generic Projects vs Construction vs PJ

| Area | Generic Projects (PM) | Construction Extension (CN) | Project Management (PJ) |
|---|---|---|---|
| Project, Task, Budget | Core | Reused and extended | Referenced |
| Account Groups and Transactions | Core | Reused | Referenced indirectly |
| Billing Rules, Rate Tables, Allocation | Core | Reused with construction-heavy billing scenarios | Usually not primary |
| Change Requests / Change Orders | Core project change control | Heavily used in construction scope control | May be triggered by PJ docs |
| Commitments | Generic PO/external commitments | Adds Subcontracts and construction commitment semantics | Usually referenced only |
| Retainage | May appear in project billing/payables context | Central in construction billing and settlement | Referenced indirectly |
| Compliance / Lien Waivers / Joint Payments | Not central | Core construction controls | Not primary owner |
| Progress Worksheets / AIA Reporting | Not central or not required in all project scenarios | Central in construction progress billing | Supporting context only |
| RFI / Issue / Daily Field Report / Drawing / Photo / Submittal | Not primary | Construction-focused | Core |
| Project Inventory Tracking | Project-aware material control | Especially important in construction/material-intensive projects | Referenced by field workflows |

### 12.2 Optional and Specialized Overlays

Some business scenarios add specialized overlays without changing the basic domain skeleton, for example:

- labor-rate-heavy service projects
- material-intensive construction projects
- certified or regulated labor scenarios
- high-retainage construction jobs
- strong compliance-gated payment processes

AI agents should treat these as **variations on the core model**, not as unrelated subdomains.

---

## 13. Guidance for Prototyping New Features

This section is intentionally pragmatic.

### 13.1 High-Value Extension Patterns

#### A. Field Event to Financial Consequence

Examples:

- Project Issue automatically proposes a Change Request
- Daily Field Report evidence influences cost forecast or delay risk
- RFI resolution updates expected budget exposure

This is usually a **PJ -> PM/CN** feature.

#### B. New Billing Logic or Commercial Rule

Examples:

- new markup basis
- special rate selection logic
- alternative invoice grouping behavior
- retainage-aware commercial review enhancements

This usually belongs in **billing policy** rather than in actual transaction logic.

#### C. New Commitment or Vendor-Control Scenario

Examples:

- richer subcontract visibility
- enhanced commitment classification
- compliance-sensitive commitment workflow
- cross-reference from changes to vendor obligations

This usually spans **PM + CN + PO/AP**.

#### D. New Forecasting and Profitability Intelligence

Examples:

- AI-assisted expected final cost
- overrun risk scoring
- forecast revision support with explanation traces
- cost-to-complete analysis with operational signals

This should extend the **forecast/projection layer**, not overwrite actuals or approved budget.

#### E. New Material or Site-Stock Feature

Examples:

- project-specific stock visibility
- material staging by project/task/location
- return and reallocation analysis

This usually spans **PM/CN + IN**, using project inventory semantics.

#### F. New Cross-Domain Workflow Automation

Examples:

- AP bill compliance hold visible in project workspace
- CRM opportunity converted into standardized project setup
- project close checklist spanning AR/AP/retainage/compliance statuses

These are classic **cross-module orchestration** features.

#### G. New Pre-Project Proposal or Conversion Feature

Examples:

- Project Quote conversion into a standardized project
- template-driven proposal defaults
- quote-to-budget or quote-to-task review support

This usually spans **PM + CR**, and the design must preserve the boundary between proposal context and approved project accounting truth.

#### H. New Rate, Allocation, WIP, or Unbilled Review Feature

Examples:

- rate selection explanation
- allocation preview or audit support
- WIP adjustment review
- unbilled amount investigation

This usually belongs in the **derived project accounting control layer**. It should explain or derive amounts without creating a parallel source of actual cost, AR invoicing, or GL ownership.

### 13.2 Recommended Design Heuristics

When designing a feature, prefer the following reasoning shortcuts:

- If it changes **what may become a project**, it is quote/proposal related.
- If it changes **what we expect**, it is budget or forecast related.
- If it changes **what we are committed to buy**, it is commitment related.
- If it records **what already happened**, it is actual transaction related.
- If it changes **how an amount is derived from existing transactions**, it is rate/allocation/WIP related.
- If it changes **what the customer can be charged**, it is billing related.
- If it changes **what is formally approved scope**, it is change-order related.
- If it changes **whether someone may be paid**, it is compliance related.
- If it starts from **field communication or site evidence**, it is PJ initiated.

---

## 14. Anti-Patterns to Avoid

The following mistakes produce poor designs in this domain.

1. **Creating a parallel actuals ledger**
   instead of using project transactions sourced from the real operational or financial documents.

2. **Using uncontrolled budget edits**
   where the business meaning is actually "pending change" or "approved change order."

3. **Treating PJ documents as financial truth**
   instead of using them as evidence, trigger, or coordination artifacts.

4. **Ignoring retainage**
   in construction billing or subcontract settlement features.

5. **Ignoring compliance gates**
   when changing payment, subcontract, or vendor settlement workflows.

6. **Putting AR/AP/CA ownership into PM**
   instead of keeping project semantics connected to, but distinct from, those modules.

7. **Creating a separate project-material ledger**
   when project inventory tracking already provides the right conceptual home.

8. **Using Project Task for everything**
   when some needs really belong to Account Group, Cost Code, item/resource dimension, or forecast layer.

9. **Treating forecasts as approved budget**
   instead of preserving the distinction between expectation, authorization, and actual outcome.

10. **Designing construction-only behavior as if it were generic PM**
    without checking for subcontracts, compliance, progress worksheets, retainage, AIA-style reporting, or PJ workflows.

11. **Treating a Project Quote as an approved Project**
    instead of preserving the proposal-to-project conversion boundary.

12. **Treating allocations, WIP, or unbilled summaries as original source activity**
    instead of tracing them back to project transactions and final financial ownership.

13. **Treating attached files as the business document**
    instead of using them as evidence linked to a project entity, PJ document, change, transaction, or source invoice.

---

## 15. Questions AI Agents Should Answer Before Proposing a Feature

Before finalizing a design, an AI agent should be able to answer these questions:

1. What real-world event is being modeled?
2. Which domain concept owns that event?
3. Does it change expectation, obligation, actual, billing, retainage, compliance, or cash?
4. Is the feature generic PM, construction-specific CN, PJ-only, or cross-domain?
5. What is the source of truth for the data involved?
6. Does the feature require approval, audit trail, or conversion from one document type to another?
7. At what granularity should it work: Project, Task, Budget line, Commitment line, or document level?
8. Does it touch retainage, compliance, subcontracts, or project inventory?
9. Does it introduce forecast meaning that must remain distinct from approved budget?
10. Does it start from a Project Quote or proposal that must remain separate from approved project accounting?
11. Does it derive amounts through rates, allocation, WIP, or unbilled review rather than creating original actuals?
12. Does it depend on project files or attachments as evidence rather than business state?
13. How will the user trace impact from origin to financial/commercial outcome?

If these questions cannot be answered clearly, the design is probably not yet aligned with the domain.

---

## 16. Compact Reference Model

The most compact correct mental model of this domain is:

- **Project Quote** is pre-project proposal context.
- **Project** is the business boundary.
- **Task** is the primary execution and control subdivision.
- **Budget** expresses authorized or expected plan.
- **Forecast** expresses expected final outcome.
- **Commitment** expresses future obligation.
- **Transaction** expresses actual realized impact.
- **Rate / Allocation / WIP** express derived project accounting control over existing activity.
- **Billing** expresses monetization of project work.
- **Retainage** expresses deferred settlement.
- **Compliance** expresses eligibility and risk control.
- **Change Request / Change Order** express controlled scope evolution.
- **PJ Documents** express field and communication reality.
- **Project Files** express linked evidence and document organization.
- **AR/AP/PO/IN/GL/CA/EP/CR** remain neighboring modules with their own ownership.

A feature is well-designed when it strengthens this model rather than fragmenting it.

---

## 17. Out of Scope for This Document

The following topics are intentionally outside this document’s scope and should be handled in separate contexts when needed:

- implementation classes, DACs, graphs, and APIs
- eventing and workflow engine internals
- database and persistence rules
- screen and UI wiring
- security implementation details beyond conceptual grouping
- tax and localization details
- deep payroll internals
- equipment and asset management details beyond their project-domain meaning
- report definitions and analytics implementation details

---

## 18. Final Guidance for AI Agents

When prototyping in this domain, default to the following posture:

- model the business event first,
- respect source-of-truth boundaries,
- separate proposal, execution, derived accounting review, and final financial ownership,
- keep expectation / obligation / actual / billing / retainage / cash distinct,
- treat Construction as an extension of Project Accounting rather than a separate universe,
- and treat PJ as the operational evidence and collaboration layer that often initiates financial consequences.

If a proposed feature cannot be explained in those terms, it is probably either too technical for this document or not yet properly aligned with the business model.
