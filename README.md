# Process Configuration & Execution Application

## 1. Objective
This Salesforce-native application enables users to define, configure, and execute **reusable business processes** that can be associated with any Salesforce object. It provides a **flexible and dynamic framework** for orchestrating multi-step workflows with branching logic, subprocesses, and rule-driven execution — all configurable declaratively by business users.

### Key Capabilities
- Associate processes with any **standard or custom object**.
- Define **ordered or parallel steps** with configurable logic.
- Support **subprocesses** (child processes spawned dynamically).
- Enable **business rules** to guide flow and transitions.
- Provide a **user-friendly interface** for admins and end users.
- Support **dynamic resolution of record targets** using polymorphic identifiers.

---

## 2. Functional Requirements

### 2.1 Process Configuration
- Users can create named **Process Templates**.
- Templates may be associated with **one or more Salesforce object types**.
- Each template defines a list of **Steps** with sequence and logic.
- Processes can **spawn subprocess templates dynamically** during execution.
- Each template supports **business rules** that determine step advancement, branching, and subprocess initiation.
- Supports **sequential** and **parallel** step execution models.

### 2.2 Step Management
Each step is a discrete unit of execution with configurable metadata:
- **Name**, **Sequence**, and **Execution Logic**
- **Step Type** (e.g., Task, Flow, Approval, Integration)
- **Entry/Exit Criteria** (formula or logic-based)
- **Execution Context:** auto-run, user input, or subprocess trigger
- **Step Outcomes:** trigger another step, subprocess, or external event (optional)
- **Status Tracking:** Not Started, In Progress, Overdue, Completed, Skipped, Failed
- **Due Date Handling:** defined by template
- Supports **parallel in-progress steps**

### 2.3 Process Execution
- Processes can be **started manually** or **triggered automatically** from records.
- Runtime logic follows entry/exit conditions and process rules.
- Supports:
  - Automatic advancement of steps when criteria are met.
  - Branching logic via process rules.
  - Step retry or skip per rule definitions.
  - **Subprocesses** as linked child process instances that can run in parallel or synchronously.

### 2.4 Polymorphic Record Targeting
- Supports any Salesforce object through:
  - `Target Record Id` (Text 18)
  - `Target Object Type` (Text)
- At runtime, Apex dynamically resolves and interacts with the record using these fields.
- All record operations respect current user permissions and context.

### 2.5 User Interface
**Admin UI:**
- Create/edit process templates.
- Configure steps, rules, and subprocesses.
- Define entry/exit conditions.

**End-User UI:**
- View progress of processes related to a record.
- Track step status and required conditions.
- Manually advance or retry steps where permitted.
- Optional: dynamic record selection for runtime targeting.

---

## 3. QA / Monitoring

### 3.1 Performance & Scalability
- System designed for **high process volume**.
- **Asynchronous operations** for long-running or external integrations.

### 3.2 Monitoring & Observability
- Log all process and step transitions on target records.
- Capture and expose **failure and error states** for reporting.
- Enable admins to query or visualize process health across records.

---

## 4. Customization & Extensibility
- Steps can invoke **Salesforce Flows** or **Apex Invocable Methods**.
- Support for **external callouts** (via Named Credentials or External Services).
- Subprocesses can instantiate other processes with **parameterized inputs**.

---

## 5. Object Model Overview

The attached **Entity Relationship Diagram (ERD)** outlines the primary objects and their relationships 【28†ERD.pdf†L1-L20】:

### Core Entities
- **Process__c** – Represents a running process instance. Includes fields such as:
  - `ProcessTemplateId__c` (lookup to template)
  - `ParentProcessId__c` (for subprocess hierarchy)
  - `Target Object Id` and `Target Object Type`
  - `Status`, `StepsToComplete`, `DueDate`

- **ProcessTemplate__c** – Defines reusable templates:
  - `ParentProcessTemplateID__c` (for hierarchical subprocess structure)
  - `StepsToComplete`, `DueInValue`, `DueInUnits`
  - `Active`, `CanStartProcess__c`

- **ProcessRule__c** – Defines logic and branching rules:
  - `FieldName`, `Operator`, `Value`, `Order`, `Active`
  - Associated with a **Process Template**

- **Related_Process_Template__c** – Links templates to subprocess templates:
  - `ParentProcessTemplateID__c`
  - `SubProcessTemplate__c`
  - `InProgressRequirement`, `CustomLogicInProgress`

- **CustomProcessor__c** – Enables custom Apex-based logic extensions:
  - `ApexClassName`
  - `Related_Process_Template__c`

> Refer to the diagram on page 1 of the attached ERD for visual representation of these relationships and key field mappings.

---

## 6. Running Tests
Developers can execute the Apex test suite using the following command:

```bash
sf apex run test --suite-names "SimpleProcessTests" --code-coverage --result-format human --wait 10
```

This suite validates:
- Process creation, execution, and rule advancement.
- Subprocess instantiation and completion.
- Entry/exit condition logic.
- End-user interactions and UI-driven state changes.

---

## 7. Summary
This application provides a robust and extensible Salesforce-native framework for dynamic process orchestration. Its design allows for:
- Declarative configuration by business users.
- Programmatic extensibility for developers.
- Scalable execution with strong observability.

The underlying model (Process, ProcessTemplate, Rules, and Subprocess relationships) supports both simple and complex workflows, enabling consistent automation and traceability across all Salesforce objects.

