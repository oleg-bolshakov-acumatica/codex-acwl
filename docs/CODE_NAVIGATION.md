# Acumatica ERP Code Navigation Guide

> Generated from repository analysis.
>
> Repository: the Acumatica ERP product source checkout (the `code/` directory of this workspace). All paths below are relative to that repository root.
>
> Repository revision: branch `2026r250`, commit `ae7e942ee9cc` (2026-07-30)
>
> Generated or verified: 2026-08-01
>
> Primary focus: PM / CN / PJ (Projects & Construction)

## 1. Purpose

This is a routing map for the repository, not source documentation. It answers: where to go, what to search for, which names to use, how to tell layers apart, and when to switch from application code to platform analysis. It intentionally names only representative, verified examples — never full inventories.

It complements (and does not repeat) the other workspace docs: `ARCHITECTURE_RULES.md` (how to write framework-correct code), `BUSINESS_MODEL.md` (PM/CN/PJ domain concepts), `DATABASE_MODEL.md` (persistence model for support analysis), `FEATURE_IMPLEMENTATION_PATTERNS.md` and `REFACTORINGS.md` (implementation quality).

## 2. How to use this map

- Start from the strongest anchor you have: ScreenID → §5/§11; DAC or table → §5/§9; module → §6/§7; framework mechanism → §8.
- Rely on the stable orientation points: directories, project names, namespaces, base classes, naming conventions. Concrete class names are verified examples for the revision above, not guarantees for later revisions.
- Statements marked *(observation)* are version-specific and drift faster than the structural rules.

Authority and limits:

- This map is authoritative for **navigation only**. It is never evidence for a finding — open the real file, verify the behavior there, and cite that file.
- For where **new** code belongs, `ARCHITECTURE_RULES.md` (§11 File Placement Guidelines) takes precedence; this map describes where existing code already is.
- The map was generated from the revision in the header. On other product branches — older support branches in particular — confirm that a referenced project, folder, or file exists before relying on it, and report material layout differences.

## 3. Top-level repository structure

| Path | Content |
|---|---|
| `PureWithNetTools.sln` | Main solution: platform + application |
| `NetTools/` | Platform/framework code (§8) |
| `WebSites/Pure/` | The ERP application: business modules, site, shipped data, app tests |
| `WebSites/Pure/PX.Objects/` | Monolithic application assembly; one folder per module (`AP`, `AR`, `GL`, `IN`, `PM`, `CN`, `CT`, `EP`, `PO`, `SO`, …) |
| `WebSites/Pure/PX.Objects.*/` | Satellite application projects (`PX.Objects.PM`, `.PM.ChangeRequest`, `.PM.MaterialManagement`, `.PJ`, `.PR`, `.FS`, `.AM`, …) |
| `WebSites/Pure/Site/` | ASP.NET site: classic pages, Modern UI sources, reports, runtime engines (wiki, GI, customization) |
| `WebSites/Pure/DB/` | Shipped data and migrations: update scripts, `EntityXml/` no-code seed data, contract-based API endpoint definitions |
| `WebSites/Pure/AppTests/` | Application test projects (xUnit) |
| `ClientSideApps/` | Shared Modern UI TypeScript library (`client-controls/`) and frontend build tooling |
| `DatabaseModel/` | SSDT schema project: one `.sql` per table under `Application/<MOD>/` and `System/` |
| `Common/` | Shared test utilities (`PX.Tests.Common`) |
| `NetTools/Tests/` | Platform test projects |

Special-purpose trees you normally skip (§12): `AcumaticaInstall/`, `Installer/`, `UpdateService/`, and the non-product sites under `WebSites/` (`TestPortal`, `ContractBasedAPITests`, `SupportPortal`, `HelpDesk`, `Customizations`, …).

## 4. Distinguishing platform code from application code

| Signal | Platform | Application |
|---|---|---|
| Directory | `NetTools/**`, `ClientSideApps/**` | `WebSites/Pure/**` |
| Namespace | `PX.Data*`, `PX.Common*`, `PX.Web.UI*`, `PX.Api.*`, `PX.Reports*`, `PX.SM`, `PX.SiteMap*`, `PX.BusinessProcess`, `PX.PushNotifications`, `PX.DbServices*`, `Customization` | `PX.Objects.*`, `PX.Commerce.*`, app data-sync providers |
| Assembly | `PX.Data.dll`, `PX.Common.dll`, `PX.Web.UI.dll`, … | `PX.Objects.dll`, `PX.Objects.<X>.dll` |
| Reference direction | referenced *by* the application | references platform binaries via `..\Site\Bin\*.dll` HintPaths |

Verified dependency rule: `PX.Objects.csproj` consumes platform assemblies as binary references only; no `NetTools/` project references `PX.Objects` (only auxiliary tooling does). The platform may still late-bind application types by string — e.g. `NetTools/PX.Data/Access/Features.xml` names `PX.Objects.CS.FeaturesSet`.

Traps — do not classify by folder name alone; confirm namespace and project references:

- The `PX.SM` namespace (users, roles, site map, schedules) is implemented in platform code: `NetTools/PX.Data/Maintenance/`, `NetTools/PX.Data/Process/`, `NetTools/PX.SiteMap/`. `WebSites/Pure/PX.Objects/SM/` is only a thin application overlay of it.
- The `PX.Api` namespace (import/export scenarios, screen-based SOAP) lives in platform `NetTools/PX.Data/Api/`.
- The `PX.Web.Customization` project uses the root namespace `Customization`.
- `WebSites/Pure/PX.Web.Controls/` and `WebSites/Pure/PX.Web.Objects/` are application-side UI helpers despite platform-sounding names.

## 5. Quick search algorithm

1. **ScreenID known** (`XX999999`): the two-letter prefix is the module. Classic page: `WebSites/Pure/Site/Pages/<MOD>/<ID>.aspx` → graph type in the `PXDataSource` tag (`TypeName=`; grep case-insensitively — lowercase `typename=` also occurs). Modern screen: `WebSites/Pure/Site/FrontendSources/screen/src/screens/<MOD>/<ID>/<ID>.ts` → `@graphInfo({ graphType: "…" })`. A screen may exist in one or both stacks.
2. **Graph known**: file is usually `WebSites/Pure/PX.Objects/<MOD>/<Graph>.cs` or in a satellite project. Then check `<Graph>_Workflow.cs` next to it and grep `PXGraphExtension<<Graph>` repo-wide for extensions.
3. **DAC or table known**: DAC file `PX.Objects/<MOD>/DAC/<Name>.cs` (prefix = module; table name = DAC name); schema `DatabaseModel/Application/<MOD>/<Table>.sql`; DAC extensions: grep `PXCacheExtension<<DAC>`.
4. **Field behavior**: attributes on the DAC field → module attribute definitions in `<MOD>/Descriptor/` → platform attributes in `NetTools/PX.Data/Descriptor/`.
5. **Behavior not in graph code**: check workflow (`*_Workflow.cs`), declarative shipped data (`WebSites/Pure/DB/EntityXml/`), then the platform mechanism (§8).
6. Still nothing → fallback algorithm in §13.

## 6. Project and Construction

Three code homes, all application-side:

- `WebSites/Pure/PX.Objects/PM/` — project accounting (in the monolith);
- `WebSites/Pure/PX.Objects/CN/` — construction features layered over other modules (in the monolith);
- satellite projects `PX.Objects.PJ`, `PX.Objects.PM`, `PX.Objects.PM.ChangeRequest`, `PX.Objects.PM.MaterialManagement` under `WebSites/Pure/`.

Assembly dependency chain (verified from csproj): `PX.Objects` ← `PX.Objects.PM.ChangeRequest` ← `PX.Objects.PJ` ← `PX.Objects.PM` (satellite). `PX.Objects.PM.MaterialManagement` depends only on `PX.Objects`.

Feature gates for the area live in `WebSites/Pure/PX.Objects/CS/DAC/FeaturesSet.cs`: `projectAccounting`, `construction`, construction project management.

### 6.1 PM — Project Accounting

Root `WebSites/Pure/PX.Objects/PM/`, namespace `PX.Objects.PM` almost everywhere (sub-namespaces are rare, e.g. `PX.Objects.PM.ProjectParentChild`).

| Area | Where (under `PM/`) | What to look for |
|---|---|---|
| Graphs | root `*.cs` | `*Entry`/`*Maint`/`*Process`/`*Inquiry`; e.g. `ProjectEntry` (PM301000), `ProjectTaskEntry`, `RegisterEntry` (PM transactions), `ChangeOrderEntry`, `ProformaEntry`, `ProgressWorksheetEntry`, `PMQuoteMaint`, `AllocationProcess`, `BillingProcess`, `RegisterRelease` |
| Data model | `DAC/` | one DAC per file: `PMProject`, `PMTask`, `PMTran`, `PMRegister`, `PMBudget`, `PMChangeOrder`, `PMProforma`, `PMCommitment`, `PMSetup`; `DAC/Lite/` — slim query variants |
| Attributes | `Descriptor/` | `ProjectAttribute`, `ProjectTaskAttribute`, `ActiveProjectTaskAttribute`, `ProjectDefaultAttribute`, `CostCodeAttribute`, `AccountGroupAttribute`, `PMCommitmentAttribute`. Note: `ActiveProjectAttribute` is defined in `GL/Attributes/ActiveProjectAttribute.cs` |
| Cross-module hooks | `GraphExtensions/` | extensions targeting AP/AR/IN/GL/PO/SO/EP graphs (§6.5); themed subfolders `CostCenter/`, `SingleProject/`, `TaxZone/`, `ProjectSpecificBranch/`, `MaterialManagement/` |
| DAC extensions | `CacheExtensions/` | `PXCacheExtension` over other modules' DACs |
| Workflow | root, `<Graph>_Workflow.cs` / `<Graph>_ApprovalWorkflow.cs` | §10 |
| Engines/services | root | `PMBillEngine` (billing engine implemented as a graph), `PMAllocator`, `RateEngine`, `BudgetService`, `ProjectBalance`. DI registration is in `WebSites/Pure/PX.Objects/ServiceRegistration.cs` (no PM-local registration) |
| Project 360 | `Project/` | `ProjectOverview` (PM301500), side panels/charts; `Project/Shared/ProjectEntryBase.cs` — shared base of `ProjectEntry` and `ProjectOverview` |
| Row-level access | `EntityAccess/`, `VisibilityRestriction/` | project/account-group access graphs, restriction classes |
| Feature slices | `Features/` | e.g. `ProjectParentChild/` |

Satellite projects:

- `WebSites/Pure/PX.Objects.PM/` — additive features over the monolith: `ProjectAudit/`, `BudgetOverrunInquiry.cs`, `Extensions/BudgetControl/` (budget control over `APInvoiceEntry`, `POOrderEntry`, `ChangeOrderEntry`).
- `WebSites/Pure/PX.Objects.PM.ChangeRequest/` — the Change Requests feature: `ChangeRequestEntry.cs` (PM308500) plus extensions into `ChangeOrderEntry`/`ProjectEntry`.
- `WebSites/Pure/PX.Objects.PM.MaterialManagement/` — project material lists and warehouse integration (`ProjectMaterialListEntry`, Modern-UI-only screen PM306500), IN/PO/SO extensions.

### 6.2 CN — Construction

Root `WebSites/Pure/PX.Objects/CN/`, namespaces `PX.Objects.CN.*`. Layout convention: `CN/<Feature>/<TargetModule>/{DAC,CacheExtensions,GraphExtensions,Graphs,Services,Descriptor}` — the second level names the *feature*, the third names the *module being extended*.

| Feature | Where (under `CN/`) | What / attaches to |
|---|---|---|
| Compliance & lien waivers | `Compliance/` | `ComplianceDocument` DAC, `ComplianceDocumentEntry` (CL401000); generic `ComplianceViewEntityExtension<TGraph,TDac>` instantiated over AP/AR/PO/PM graphs; lien-waiver processing |
| Subcontracts | `Subcontracts/` | `Subcontract : POOrder` (same table), `SubcontractEntry : POOrderEntry` (SC301000); per-module hooks in `Subcontracts/{AP,CR,CS,EP,PM,PO,RQ,SM}/` |
| Joint checks | `JointChecks/` | joint payees on AP bills/payments; extensions over `APPaymentEntry`, `APReleaseProcess` |
| Vendor requirements | `Requirements/` | `VendorDocumentReqMaint` (CL201000, Modern-only); compliance sync with PO |
| Construction project accounting | `ProjectAccounting/` | `CostProjectionEntry` (hosted on PM screen PM305000); AP/AR/EP/IN/PO extensions |
| CRM overlay | `CRM/` | multiple project quotes per opportunity (`OpportunityMaint` extension) |
| Shared infrastructure | `Common/` | data providers (`IProjectDataProvider`, …), DI module `Common/DependencyInjection/Registration.cs`, shared attributes |
| Mobile behavior | `Mobile/` | mobile-specific selectors/defaulting for EP time cards |

CN has **no screen prefix of its own**: Compliance uses `CL*`, Subcontracts use `SC*`, the rest rides `PM*` screens. There is no `Pages/CN` and no `screens/CN`. Reports follow the same prefixes (`CL*.rpx`, `SC*.rpx`).

### 6.3 PJ — Construction Project Management

Separate project `WebSites/Pure/PX.Objects.PJ/`. Namespace pattern `PX.Objects.PJ.<Area>.<ModuleCode>.<Layer>`, e.g. `PX.Objects.PJ.RequestsForInformation.PJ.Graphs.RequestForInformationMaint`. Per-area layout mirrors CN: `<Area>/<ModuleCode>/{DAC,Descriptor,CacheExtensions,GraphExtensions,Graphs,Services}` where `PJ` holds the area's own artifacts and `PM/CR/EP/CS/SM` hold integration hooks.

Areas *(observation of the current set)*: `DailyFieldReports` (PJ304000; third-party weather providers under `External/`), `RequestsForInformation` (PJ301000), `Submittals` (PJ306000), `DrawingLogs` (PJ303000), `PhotoLogs` (PJ305000), `ProjectsIssue` (PJ302000), `ProjectManagement` (shared base `ProjectManagementBaseMaint<TGraph,TEntity>` and class/setup screens PJ201000/PJ101000), `ProjectOverview`, `ProjectAccounting`, `OutlookIntegration`, `ProjectFiles`, `Common` (own DI `ServiceRegistration`).

Quirk: `ProjectFiles/` uses namespace `PX.Objects.PM.ProjectFiles.*` and PM screen numbers (PM509000/PM509500) although it lives in the PJ project.

### 6.4 Shared Project & Construction mechanics

- **`PMProject : PX.Objects.CT.Contract`** — projects and contracts share the `Contract` table (`DatabaseModel/Application/CT/Contract.sql`; there is no `PMProject.sql`). Expect `ContractID` fields that mean "project or contract" (e.g. on `EP/DAC/EPExpenseClaimDetails.cs`).
- **`PMQuote`** is a `PXProjection` over CRM quote tables (`CR.Standalone.CRQuote` + `CROpportunityRevision`); `PMQuoteMaint` is an independent graph, not derived from CR's `QuoteMaint`.
- **`PMTimeActivity`** physically resides in `WebSites/Pure/PX.Objects/CR/DAC/` — the shared CRM/EP/PM activity table.
- **Commitments**: `PM/DAC/PMCommitment.cs` + generic `PM/GraphExtensions/CommitmentTracking.cs` applied to PO/AP graphs.
- **Retainage**: `AP/Retainage/` and `AR/Retainage/` folders plus `AP/APRetainageRelease.cs`; PM-side hooks such as `PM/GraphExtensions/ChangeOrderEntryRetainageExt.cs`.
- **Project inventory**: `INRegister` has no project fields; the link is `IN/DAC/INCostCenter.cs` (keyed by site/location/project/task) plus `PM/GraphExtensions/CostCenter/`.
- **Account groups**: GL `Account.AccountGroupID` → `PMAccountGroup` maps GL accounts into PM.

### 6.5 Integration direction

Verified rule: integration code lives on the PM/CN/PJ side and targets other modules' graphs via `PXGraphExtension<>`. Other module folders contain almost no `PX.Objects.PM` code (notable exceptions: `GL/Attributes/ActiveProjectAttribute.cs`, a few project inquiries under `EP/`).

- **Financial release → PM**: `PM/GraphExtensions/ARDocumentReleaseExt.cs` (`ARReleaseProcessExt`), `APReleaseProcessExt.cs`, `INReleaseProcessExt.cs`, `PostGraphExt.cs` and `JournalEntryExt.cs` (GL). These attach/produce `PMTran` during release of source documents.
- **EP → PM**: `EP/TimeCardMaint.cs` and `EP/EmployeeActivitiesRelease.cs` instantiate PM `RegisterEntry` and call its `CreatePMTran`-style factory to post time to projects.
- **Document capture**: project/task/cost-code fields on `APTran`, `ARTran`, `GLTran`, `INTran`, `POLine`, `SOLine` are declared with PM `Descriptor/` attributes.
- **PM billing → AR**: `PMBillEngine`/`ProformaEntry` produce AR invoices; navigate back from `PMTran` reference fields (AR doc type/number, GL batch number).

### 6.6 PM/CN/PJ-specific search scenarios

- *Where does a project balance/budget figure change?* → `PM/ProjectBalance.cs`, `PM/BudgetService.cs`, release extensions in `PM/GraphExtensions/`, then `RegisterRelease`/`AllocationProcess`.
- *What creates `PMTran` from module X?* → grep `RegisterEntry` and `CreatePMTran` under `PX.Objects/<X>/`, and check `PM/GraphExtensions/<X>*Ext.cs`.
- *Where is the logic of a `CL*`/`SC*` screen?* → `CN/Compliance/` and `CN/Requirements/` for CL, `CN/Subcontracts/` for SC.
- *Change order vs change request?* → `PM/ChangeOrderEntry*.cs` (monolith) vs `PX.Objects.PM.ChangeRequest/` (satellite).

## 7. Adjacent application modules

All monolith modules share one anatomy — learn it once, apply everywhere:

```
PX.Objects/<MOD>/
  <Graph>.cs               entry graphs (*Entry), setup (*Maint), release (*Process / …Release)
  <Graph>_Workflow.cs      workflow partials next to the graph
  DAC/                     DACs incl. the <MOD>Setup preferences DAC
  Descriptor/              Messages.cs, module attributes, list constants
  GraphExtensions/         this module's own extensions (naming varies; GL uses GraphBaseExtensions/)
```

Preferences pattern: `<MOD>Setup` DAC + `<MOD>SetupMaint` graph (occasional deviations: FA uses `SetupMaint`, CT has no setup DAC).

| Module | Entry points (verified) | Release / posting | PM/CN/PJ touchpoints |
|---|---|---|---|
| **IN** Inventory | `INReceiptEntry`, `INIssueEntry`, `INAdjustmentEntry`, `INTransferEntry` (base `INRegisterEntryBase`) | `IN/InventoryRelease/INReleaseProcess.cs`, `INDocumentRelease` | project stock via `INCostCenter`; project fields on `INTran`; `PM/GraphExtensions/IN*`; MaterialManagement satellite |
| **AR** Receivables | `ARInvoiceEntry`, `ARPaymentEntry` | `AR/ARDocumentRelease.cs` (also contains `ARReleaseProcess`) | pro forma → AR invoice; project fields on `ARTran`; `AR/Retainage/`; PM's `ARReleaseProcessExt` |
| **AP** Payables | `APInvoiceEntry`, `APPaymentEntry` | `AP/APDocumentRelease.cs` (also contains `APReleaseProcess`) | subcontract/commitment billing; project fields on `APTran`; `AP/Retainage/` + `APRetainageRelease`; CN joint checks & lien waivers |
| **GL** General Ledger | `JournalEntry` | `PostGraph` (same file `GL/JournalEntry.cs`) | `Account.AccountGroupID` → `PMAccountGroup`; project fields on `GLTran`; PM's `PostGraphExt`/`JournalEntryExt` |
| **CR** CRM | `OpportunityMaint`, `BusinessAccountMaint` (per-graph folders `CR/Graphs/<Name>/`) | — | `PMQuote` projection over CR quotes; `PMTimeActivity` DAC lives here; CN multi-quote overlay |
| **EP** Time & Expenses | `TimeCardMaint`, `ExpenseClaimEntry`; approvals `EPApprovalProcess` | `EPReleaseProcess`, `EmployeeActivitiesRelease` | time/expenses become `PMTran` via PM `RegisterEntry`; approval maps used by PM/CN/PJ approval workflows |
| **PR** Payroll | real code in satellite `WebSites/Pure/PX.Objects.PR/` (`PRPayChecksAndAdjustments` family, `PRCalculationEngine.cs`); monolith `PX.Objects/PR/` holds only `PX.Objects.PR.Standalone` stub DACs | `PRDocumentProcess.cs` | certified projects, labor cost rates ↔ PM; `PX.Objects.PJ` references the PR project |
| **PO** Purchasing | `POOrderEntry`, `POReceiptEntry` | none of its own — receipt release drives IN/AP | commitments (`POCommitmentAttribute`); subcontracts derive from PO; project fields on `POLine` |
| **SO** Sales Orders | `SOOrderEntry`, `SOShipmentEntry`, `SOInvoiceEntry : ARInvoiceEntry` | via AR/IN | project shipments via cost centers; project fields on `SOLine` |
| **CT** Contracts | `ContractMaint`, `UsageMaint`, `ContractBilling` + `CTBillEngine.cs` | — | base DAC `Contract` of `PMProject`; a billing engine parallel to PM's |

One-line pointers for the rest: **CA** cash management (`CATranEntry`); **CM** currency (`CuryRateMaint`; reusable multi-currency logic in `PX.Objects/Extensions/MultiCurrency/`); **CS** common setup (`FeaturesSet`/`FeaturesMaint`, numbering, attributes, dimensions, branches); **TX** taxes (`SalesTaxMaint`); **DR** deferred revenue; **FA** fixed assets; **RQ** requisitions (subcontract hooks); **SM**/**AU** thin app overlays of platform system management and schedules.

Shared application-level code: `PX.Objects/Common/` (cross-module helpers, no graphs), `PX.Objects/Extensions/` (reusable graph/DAC extension patterns: MultiCurrency, Discount, SalesTax, CostAccrual, …), `PX.Objects/EndpointAdapters/` (contract-based API endpoint implementations, incl. a PM one), `PX.Objects/ServiceRegistration.cs` (Autofac module registering app services).

## 8. Platform code map

Everything below is under `NetTools/` unless stated otherwise. Format: where — key types — when to descend.

### 8.1 Graph framework
`PX.Data/Graph/` — `PXGraph` (`Graph.cs`), `PXGraphExtension` (`GraphExtension.cs`), extension discovery (`ExtensionManager.cs`); actions in `PX.Data/Descriptor/Action/PXAction.cs`; `PXView` in `PX.Data/Database/Cached.cs`. Descend for: graph lifecycle, view/action discovery, `PXOverride` mechanics.

### 8.2 DAC and data access
`PX.Data/BQL/` (`IBqlTable`, `PXBqlTable`), `PX.Data/Cache/` (`PXCache`, `PXCacheExtension`), `PX.Data/Descriptor/` (all `PXDB*`, `PXUIField`, `PXDefault` attributes), `PX.Data/ReferentialIntegrity/` (`PrimaryKeyOf<>`, `ForeignKeyOf<>`). Descend for: attribute behavior, cache state, key definitions.

### 8.3 BQL
Classic grammar in `PX.Data/BQL/` (Select/Search/Where/Join); `PXSelect*` view wrappers in `PX.Data/Graph/Indexer.cs`. Fluent BQL in `PX.Data.BQL.Fluent/` (`SelectFrom<>`, `PXViewOf<>`, `FbqlCommand`). Descend for: query translation and overload resolution.

### 8.4 Events and cache pipeline
Classic event args in `PX.Data/Cache/Event.cs`; typed generic events in `PX.Data/Graph/Events/`; dispatch in `PX.Data/Cache/ModelEventHandling.cs`. Descend for: handler ordering, auto-subscription, `CacheAttached`.

### 8.5 Persistence and database
`PX.Data/Database/` (`PXDatabase`, `PXTransactionScope`, MSSQL provider, `ISqlDialect`); MySQL in `PX.MySql/`, PostgreSQL in `PX.PgSql/`; bulk/script execution in `PX.BulkInsert/`; schema model and DB services in `PX.DbServices/`. Descend for: SQL generation, transactions, provider-specific behavior.

### 8.6 UI framework
Classic WebForms: `PX.Web.UI/` (`PXGrid`, `PXFormView`, `PXDataSource`), shell `PX.Web.UI.Frameset/`; host site `WebSites/Pure/Site/` (`Pages/`, `MasterPages/`). Modern UI: server side `PX.Api.TSBasedScreen/` (+ app companion `WebSites/Pure/PX.Api.TSBasedScreen.Objects/`); client library `ClientSideApps/client-controls/` (`PXScreen`, `PXView`, controls, services); per-screen apps `WebSites/Pure/Site/FrontendSources/{screen,main-frame}/`. Classic/Modern switching: `PX.Data/Access/SiteMap/SiteMapUITypeProvider.cs`, `PX.SiteMap/UIScreenModeSwitcher.cs`. Descend for: control behavior, screen runtime, TS wrapper generation.

### 8.7 Workflow and automation
Workflow API `PX.Data/ProjectDefinition/` (namespace `PX.Data.WorkflowAPI`: `PXScreenConfiguration`, `WorkflowContext<,>`); runtime `PX.Data/Process/Automation/`; legacy automation-step DACs `PX.Data/Process/DAC/` (`AUDefinition`, `AUStep` — namespace `PX.SM`). Application side: `<Graph>_Workflow.cs` overrides `Configure(PXScreenConfiguration)`. Descend for: state/transition evaluation, workflow-driven action visibility.

### 8.8 APIs and integration
Contract-based REST `PX.Api.ContractBased/` — shipped endpoint definitions in `WebSites/Pure/DB/ContractBasedApiEndpoints/*.endpoint`, app implementations in `PX.Objects/EndpointAdapters/`. OData `PX.Api.OData/` and `PX.Api.OData.v4/`. Webhooks `PX.Api.Webhooks/`. Mobile API `PX.Api.Mobile/`. Screen-based SOAP `PX.Soap/` + `PX.Data/Api/Export/WebServiceMaint.cs`. Import/export scenario engine `PX.Data/Api/` (namespace `PX.Api`: `SYImportMaint`, `SYMapping`), data providers `PX.DataSync.Core/` and `WebSites/Pure/PX.DataSync/`. Descend for: endpoint resolution, scenario execution.

### 8.9 Processing and background operations
`PXLongOperation` in `PX.Data/Async/`; `PXProcessing*` in `PX.Data/Descriptor/Action/`; schedules in `PX.Data/Process/` (`AUSchedule*`, namespace `PX.SM`) with app overlay `PX.Objects/AU/`; business events `PX.BusinessProcess/` (+ app subscribers `PX.Objects/BusinessProcess/`); push notifications `PX.PushNotifications/`. Descend for: async state, mass-processing plumbing, scheduling.

### 8.10 Customization and no-code
Customization engine `PX.Web.Customization/` (namespace `Customization`); runtime targets in the site: `WebSites/Pure/Site/App_RuntimeCode/`, `WebSites/Pure/Site/App_Data/`. Generic Inquiry engine `PX.Data/GenericInquiry/`. Shipped no-code data: `WebSites/Pure/DB/EntityXml/` (§9). Descend for: publish/validation behavior, GI execution.

### 8.11 Migrations and upgrades
Update runtime `PX.Data/Update/`; script pipeline `PX.DbServices/Scripting/` + `PX.BulkInsert/ScriptExecutor/`; application scripts `WebSites/Pure/DB/{MSSQL,MySql,PgSql}/`; schema `DatabaseModel/`. Descend for: how update scripts are ordered, hashed, and executed.

### 8.12 Security, features, configuration
Access and identity: `PX.Data/Access/` (`PXAccess`, membership, MFA), security DACs `PX.Data/Maintenance/` (namespace `PX.SM`: `Users`, `Roles`); SSO projects `PX.OidcClient/`, `PX.TokenLogin/`, `PX.IdentityServer.UI/`. Features: platform `PXFeatureAttribute` + `PXAccess.FeatureInstalled<>` over application `PX.Objects/CS/DAC/FeaturesSet.cs`. Licensing `PX.LicensePolicy/`. Localization `PX.Data/Localization/` (`PXMessages`, `PXLocalizer`); country code packs `WebSites/Pure/Localizations/`. Site map `PX.Data/Access/SiteMap/` + `PX.SiteMap/` (DAC `PX.SM.SiteMap`). Descend for: rights evaluation, feature gating, translations, menu resolution.

### 8.13 Testing infrastructure
Platform tests `NetTools/Tests/` — suffix conventions: `*.WSDependent` requires a deployed site, `*.DbDependent` requires a database. Shared utilities `Common/PX.Tests.Common/`. Application test bases `WebSites/Pure/AppTests/PX.Objects.Tests.Common/`. Descend for: harnesses and base classes when writing tests.

## 9. Where each artifact type lives

The table describes where existing artifacts are found. For placing **new** artifacts, follow `ARCHITECTURE_RULES.md` §11.

| Artifact | Location | Notes |
|---|---|---|
| Backend logic | `PX.Objects/<MOD>/*.cs`, satellite projects | graphs, engines, services |
| Graph/DAC extensions | `<owner>/GraphExtensions/`, `<owner>/CacheExtensions/` | live with the *extending* feature, not with the target module |
| Data model | `<MOD>/DAC/` | keys as nested `PK`/`FK` classes; projections are DACs with `PXProjection` |
| DB schema | `DatabaseModel/Application/<MOD>/<Table>.sql`, `DatabaseModel/System/` | file per table; files are picked up by folder, no per-file project registration |
| Migrations | `WebSites/Pure/DB/MSSQL/AppUpdates_<order>_<team>.sql` | Projects team → `AppUpdates_500_PROJ.sql`; per-statement tags `--[MinVersion(…)]`, `--[IfExists(…)]`, `--[mssql|mysql|pgsql: …]`; `MySql/`/`PgSql/` dirs hold only merged files |
| Classic UI | `WebSites/Pure/Site/Pages/<MOD>/<ScreenID>.aspx(.cs)` | graph bound in the `PXDataSource` tag |
| Modern UI | `WebSites/Pure/Site/FrontendSources/screen/src/screens/<MOD>/<ID>/` | `<ID>.ts` + `<ID>.html` + `views.ts` (+ `extensions/`); shared controls in `ClientSideApps/client-controls/` |
| Reports | `WebSites/Pure/Site/ReportsDefault/<ScreenID>.rpx` | flat folder; locale variants `<ID>.<CC>.rpx` |
| No-code seed data | `WebSites/Pure/DB/EntityXml/<Kind>/` | `Generic Inquiries/` (one XML per GI), `SiteMap/SiteMap.xml`, `MobileSiteMap/<ScreenID>-add.xml` (MSDL script inside XML), `BusinessEvents/`, `Scenarios/`, `Filters/`, `Dashboards/`, `Notification/`, … |
| CB API endpoints | `WebSites/Pure/DB/ContractBasedApiEndpoints/*.endpoint` | versioned per release |
| Data-consistency checks | `WebSites/Pure/DB/DataConsistency/` | incl. `DataConsistencyValidation_ProjectConstruction.sql` |
| Application tests | `WebSites/Pure/AppTests/PX.Objects.Tests/<MOD>/` | xUnit; `PM/`, `CN/`, `PJ/` folders exist |
| Platform tests | `NetTools/Tests/` | see §8.13 |

## 10. Naming conventions and search patterns

Conventions:

- Graphs: `*Entry` (documents), `*Maint` (reference/setup), `*Process` (mass operations), `*Inquiry`/`*Enq` (inquiries).
- Workflow: `<Graph>_Workflow.cs`; approvals: `<Graph>_ApprovalWorkflow.cs` — implemented as `PXGraphExtension<<Graph>_Workflow, <Graph>>` (an extension of the workflow extension), gated by `FeaturesSet.approvalWorkflow` plus the module setup record.
- DACs: `<MOD><Entity>`; file name = class name = table name (schema file matches).
- Screen IDs: `<MOD><6 digits>`; mobile list/pickup variants `<MOD><4 digits>PL`.
- Tests: usually `<TypeName>Tests`, but not reliably — search test *content*, not file names.

Search recipes (ripgrep):

- Graph for a screen: `TypeName="` in `Site/Pages/<MOD>/<ID>.aspx` (case-insensitive) or `graphType:` in `screens/<MOD>/<ID>/<ID>.ts`.
- All extensions of a graph: `PXGraphExtension<GraphName` (catches multi-parameter forms too).
- DAC extensions: `PXCacheExtension<` + DAC name.
- Action implementation: `PXAction<` + name, or the delegate `IEnumerable actionName(PXAdapter` in the graph and its extensions; then workflow action definitions in `_Workflow.cs`.
- Feature gating: `FeatureInstalled<FeaturesSet.` + feature field.
- Tests for a type: grep the type name under `WebSites/Pure/AppTests/`.
- BQL field: DAC fields are nested lowercase classes — grep `class <fieldName>` scoped to `DAC/` folders.

Prefix pitfalls: `CL`/`SC` screens = construction compliance/subcontracts (code in `PX.Objects/CN/`); `ML` = machine learning, not material lists; the monolith `PR/` folder holds payroll stubs (real payroll is `PX.Objects.PR/`); `CT` = contracts (base of PM projects); `PJ` code can carry `PX.Objects.PM.*` namespaces (ProjectFiles).

## 11. Typical investigation routes

**Find the implementation of a screen action.** ScreenID → graph (§5) → grep the action in the graph file and in `PXGraphExtension<Graph>` results → check `<Graph>_Workflow.cs` for workflow-defined actions and state gating → if the action is generated (processing screens, auto actions), descend to §8.7/§8.9.

**From a screen to its business logic.** ScreenID → graph → views (BQL) → event handlers (graph + extensions) → attributes on DAC fields → engines/services the graph calls.

**Find a DAC by table or field.** Table name = DAC name → glob `**/DAC/<Name>.cs`; schema in `DatabaseModel/Application/`; for a field, grep the nested field class or property within `DAC/` folders.

**UI visibility/enablement source.** Check in order: `PXUIField`/`PXUIEnabled` attributes on the DAC → `RowSelected` handlers (graph and extensions) → workflow field/action states in `_Workflow.cs` → feature flags → access rights.

**Release/posting chain into PM.** Source document's release graph (§7 table) → PM extension `PM/GraphExtensions/<X>*Ext.cs` → `PMRegister`/`PMTran` creation → PM-side `RegisterRelease`, allocation, billing.

**Find a field's migration.** Current schema `DatabaseModel/Application/<MOD>/<Table>.sql`; history: grep the column in `WebSites/Pure/DB/MSSQL/AppUpdates_*.sql` (Projects changes usually in `AppUpdates_500_PROJ.sql`).

**Application or platform?** Resolve the symbol's namespace/assembly (§4). If application code shows no handlers, workflow, or attributes explaining the behavior, grep the mechanism's anchor types in `NetTools/PX.Data` (§8).

**Find no-code configuration.** `WebSites/Pure/DB/EntityXml/` by kind; GIs named `<Prefix>-<Title>.xml`; mobile `MobileSiteMap/<ScreenID>-add.xml`; menu placement in `SiteMap/SiteMap.xml`. Customer-authored configuration lives in the database, not in the repo.

**Find tests for a component.** Grep the type name under `WebSites/Pure/AppTests/PX.Objects.Tests/` (folder = module). Platform types → `NetTools/Tests/`.

## 12. What usually does not need analysis

- Build outputs and dependencies: `bin/`, `obj/`, `node_modules/`, `dist/` folders (`Site/FrontendSources/dist/`, `ClientSideApps/**`).
- Runtime working data: `WebSites/Pure/Site/App_Data/` (customization working set), `Site/App_RuntimeCode/`, `TestResults/`.
- Analyzer configs: `*.acuminator` files.
- Special-purpose trees — enter only when the task is about them: `AcumaticaInstall/`, `Installer/`, `UpdateService/` (update delivery service); non-product sites `WebSites/{SupportPortal, HelpDesk, Internal, TestPortal, ContractBasedAPITests, Customizations, CustomSolutions, DCMonitoring, OnlineProfiler, PerfWebsite, ProvisioningOperations, ProvisioningSystem, Telemetry}`; provider plug-ins (`WebSites/ExternalCarriers/`, `PX.CCProcessing.*`, `PX.TaxProvider.*`, `PX.*PlugIn`); `PX.Commerce.*` unless the task is commerce-related.
- `WebSites/Pure/Site/Wiki/` is the help/wiki *engine*, not help content.

## 13. When the map has no direct answer

1. Determine the functional module (screen prefix, DAC prefix, table name, namespace).
2. Classify the artifact type: backend / UI / data / migration / configuration.
3. Pick the most likely project and namespace (§3, §6, §7).
4. Search by the strongest key you have: ScreenID, DAC, graph, action, field name, table.
5. Check extensions and partials: `PXGraphExtension<X`, `PXCacheExtension<X`, `partial class X`.
6. Check workflow and declarative configuration: `_Workflow.cs`, `WebSites/Pure/DB/EntityXml/`, attributes.
7. Follow project references and base classes upward (satellites → monolith → platform assemblies).
8. Descend into the platform using the §8 anchors.
9. Check usages, overrides, and registrations: `PXOverride`, `ServiceRegistration`, DI modules.
10. If a stable, reusable fact emerges, add it to this map (§14).

## 14. Keeping this document current

- **Stable (low churn)**: directory layout, project boundaries, namespace patterns, naming conventions, dependency direction, artifact-type placement, search recipes.
- **Version observations (re-verify before relying)**: specific screen⇄graph pairs, satellite feature sets, area inventories, Modern-only screen lists.
- To refresh: update the revision header; spot-check the §6 examples and §9 locations against the disk; prefer deleting drifted specifics over letting them rot.
- The commit in the header dates the analysis as a whole — it does not guarantee every statement for later revisions.
