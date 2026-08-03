---
name: spdd-workflow
description: Structured Prompt-Driven Development (SPDD) — an engineering method that treats prompts as first-class, version-controlled delivery artifacts. Use this skill whenever a feature, enhancement, or refactoring task requires governed, reviewable AI-generated code. Activates the REASONS Canvas, the six-step SPDD workflow, and the core developer skills (Abstraction-First, Alignment, Iterative Review).
metadata:
  author: Thoughtworks Global IT Services / deppi team
  version: 1.0
  source: https://martinfowler.com/articles/spdd.html
---

# Structured Prompt-Driven Development (SPDD)

## What is SPDD?

SPDD turns AI assistance from **personal efficiency** into an **organization-level capability** that scales without trading away quality.

> **Core principle:** When reality diverges, fix the prompt first — then update the code.

Instead of relying on ad-hoc chat, SPDD treats prompts as assets that are:
- Version-controlled alongside code
- Reviewed by the team before code is generated
- Reused and improved across iterations
- Synchronized with the codebase at all times

---

## The REASONS Canvas

The canvas is the heart of every SPDD iteration. It is a **seven-part structured prompt** that guides the LLM from intent → design → execution → governance.

### Part breakdown

| Section | Letter | Purpose |
|---|---|---|
| **Requirements** | R | What problem are we solving? What is the Definition of Done? |
| **Entities** | E | Domain entities, relationships, and the ubiquitous language |
| **Approach** | A | The strategic solution direction and key design decisions |
| **Structure** | S | Where the change fits in the system; components and dependencies |
| **Operations** | O | Concrete, testable implementation steps (method-level granularity) |
| **Norms** | N | Cross-cutting engineering standards (naming, observability, defensive coding) |
| **Safeguards** | S | Non-negotiable constraints (invariants, performance limits, security rules) |

**Abstract parts (intent & design):** R, E, A, S
**Specific parts (execution):** O
**Governance parts:** N, S (second)

### Canvas file naming convention

```
<ID>-<YYYYMMDDHHSS>-[<Type>]-<short-description>.md

Examples:
  PROJ-001-202506021100-[Analysis]-multi-plan-billing.md
  PROJ-001-202506021105-[Feat]-multi-plan-billing.md
  PROJ-001-202506021110-[Test]-multi-plan-billing.md
```

---

## The Six-Step SPDD Workflow

### Step 1 — Create requirements (`/spdd-story`)

**Optional.** Break large requirements into independent, deliverable user stories following the **INVEST principle** (1–5 days each). Each story must have:
- Background and Business Value
- Scope In / Scope Out
- Acceptance Criteria in **Given / When / Then** format with concrete numeric examples

> Stories can be authored by PO, BA, or developer depending on team division of labor.

### Step 2 — Clarify the analysis (human step)

Before any tooling, the developer reviews the story to build shared understanding:

1. **Core logic** — What does "implement this" really mean in practice?
2. **Scope boundaries** — What are we explicitly NOT building?
3. **Definition of Done** — Enumerate testable scenarios from the ACs, adding technical detail (HTTP codes, response shapes, edge cases).

No AI at this step — this is where human intent is crystallized.

### Step 3 — Generate analysis context (`/spdd-analysis`)

Feed the user story to the analysis command. It:
- Extracts domain keywords from requirements
- Scans only the **relevant parts** of the codebase (not all of it)
- Produces a strategic document covering:
  - Domain concept recognition (existing vs. new)
  - Strategic direction and design decisions
  - Risks, ambiguities, edge cases, and AC coverage gaps

**Review checklist:**
- [ ] Does the AI's interpretation match your mental model?
- [ ] Are the proposed design patterns (Strategy, Factory, etc.) appropriate?
- [ ] Does it adhere to the OOP principles already established in the codebase (ISP, SRP, OCP)?
- [ ] Are there edge cases surfaced that you hadn't considered?

Decision: accept, refine via dialogue, or re-run.

### Step 4 — Generate the structured prompt (`/spdd-reasons-canvas`)

Feed the analysis document into the canvas generator. It produces an **executable blueprint** — precise down to method signatures, parameter types, and execution order.

**Review checklist:**
- [ ] **Architecture**: Does the solution match the system's layered/tier structure?
- [ ] **Abstraction**: Are responsibilities properly separated? No god objects or mixed concerns?
- [ ] **Business logic**: Does the Service layer precisely match the intent from Step 2?
- [ ] **Scope of change**: Are modifications strictly within the defined boundaries?
- [ ] **Norms & Safeguards**: Are all cross-cutting concerns captured?

**How to refine the canvas (never manually edit the file):**
1. Identify the gap in the canvas.
2. Describe the corrected intent in natural language in the chat.
3. Run `/spdd-prompt-update` — the AI updates only the affected sections.

### Step 5 — Generate code (`/spdd-generate`)

With the canvas locked, generate product code. The LLM reads the canvas task-by-task, following Operations order and honoring all Norms and Safeguards.

**Code review framework — two categories:**

| Category | Rule | SPDD Command |
|---|---|---|
| **Logic corrections** (behavior changes) | Update the prompt first → then generate updated code | `/spdd-prompt-update` → `/spdd-generate` |
| **Refactoring** (no behavior change) | Refactor the code directly → then sync back to prompt | Direct edit → `/spdd-sync` |

**Functional verification:**
- Run `/spdd-api-test` to generate a cURL-based test script covering normal, boundary, and error scenarios.
- Execute the script and confirm all tests pass before proceeding.

### Step 6 — Generate unit tests

Use the canvas + a test template to produce a structured test prompt, then:
1. Cross-reference generated test scenarios against the **existing test suite** to remove duplicates.
2. Generate unit test code from the deduplicated test prompt.
3. Confirm all tests pass, then commit.

---

## SPDD Command Reference

| Command | Type | When to use |
|---|---|---|
| `/spdd-story` | Optional | Break large requirements into INVEST stories |
| `/spdd-analysis` | Core | Extract domain keywords, scan code, produce strategic analysis |
| `/spdd-reasons-canvas` | Core | Generate the full REASONS Canvas (executable blueprint) |
| `/spdd-generate` | Core | Generate/update code task-by-task from the canvas |
| `/spdd-api-test` | Optional | Generate cURL-based functional test script |
| `/spdd-prompt-update` | Core | Update canvas when **requirements change** (req → prompt → code) |
| `/spdd-sync` | Core | Sync canvas when **code changes** via refactoring (code → prompt) |

---

## Three Core Developer Skills

### 1. Abstraction First — design before you generate

Before generating any code, define:
- What objects exist and how they collaborate
- Where the boundaries are (layer, module, service)
- Which design patterns apply (Strategy, Factory, Repository…)

Without this, AI sprints on implementation while structure falls apart.

### 2. Alignment — lock intent before writing code

Before implementation, make explicit:
- What we WILL do (scope in)
- What we WILL NOT do (scope out)
- Engineering standards and hard constraints

Misalignments found here are cheap. Misalignments found in code review are expensive.

### 3. Iterative Review — turn output into a controlled loop

Review in layers:
1. Does the analysis match the business intent?
2. Does the canvas match the analysis?
3. Does the code match the canvas?
4. Do the tests validate the expected behavior?

Never force the model to patch indefinitely — if drift accumulates, return to the canvas.

---

## Fitness Assessment

Use this table to decide when to apply SPDD:

| Stars | Scenario |
|---|---|
| ⭐⭐⭐⭐⭐ | Scaled, standardized delivery (many similar APIs, core business workflows) |
| ⭐⭐⭐⭐⭐ | High compliance / hard constraints (financial, security, multi-client) |
| ⭐⭐⭐⭐ | Team collaboration requiring full traceability and auditability |
| ⭐⭐⭐⭐ | Cross-cutting consistency work (refactors across microservices / languages) |
| ⭐⭐ | Firefighting hotfixes (defer governance, apply post-mortem sync after stabilization) |
| ⭐⭐ | Exploratory spikes (validate idea quickly, SPDD overhead won't pay back) |
| ⭐⭐ | One-off disposable scripts |
| ⭐ | Context black holes (domain undefined, business rules unclear) |
| ⭐ | Pure creative / visual work (UI aesthetics, marketing copy) |

---

## Hotfix Handling (special case)

When a production hotfix is needed:

**Scenario A — area has a canvas:**
1. AI analyzes the failure and root cause.
2. Apply SPDD loop in compressed form: update canvas → update code.
3. The fix becomes a permanent governed artifact.

**Scenario B — legacy code with no canvas:**
1. Fix urgently using AI-assisted analysis.
2. Run a post-mortem: synthesize the fix, failure mode, and context into new SPDD assets.
3. This is how SPDD coverage grows organically over a legacy codebase.

---

## Two-Way Sync Rule

```
Requirements changed?
  → /spdd-prompt-update  (req → prompt → code)

Code changed (refactoring)?
  → /spdd-sync           (code → prompt)
```

The canvas must **always** be an accurate record of the current system — not a historical snapshot.

---

## Quick-Start Checklist

For each new feature or enhancement:

- [ ] User story exists with clear Given/When/Then ACs and numeric examples
- [ ] Analysis clarified (scope in, scope out, DoD enumerated)
- [ ] `/spdd-analysis` run and reviewed
- [ ] `/spdd-reasons-canvas` generated and reviewed (architecture, logic, scope)
- [ ] Canvas refined via `/spdd-prompt-update` if needed
- [ ] `/spdd-generate` run — code reviewed in two passes (logic, then style)
- [ ] `/spdd-api-test` run — all functional tests pass
- [ ] Logic corrections applied via prompt-first flow
- [ ] Refactoring applied directly, then `/spdd-sync` run
- [ ] Unit tests generated, deduplicated, all passing
- [ ] Final regression run — all tests still pass
- [ ] Canvas and code committed together in version control
