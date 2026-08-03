---
name: sdd-workflow
description: Spec-Driven Development (SDD) — a three-phase AI coding workflow (Research → Spec → Code) that maximizes context window efficiency and produces simple, modular, production-ready code. Use this skill when implementing any feature, integration, or refactoring with an AI coding assistant. Prevents the 5 most common AI coding failure patterns.
metadata:
  author: Deborah Folloni / Dex Horthy (Human Layer)
  version: 1.0
  source: https://deborah-folloni.medium.com
---

# Spec-Driven Development (SDD)

## Why AI-generated code often fails

There are **5 recurring failure patterns** when coding with AI without a method:

| # | Pattern | Description |
|---|---|---|
| 1 | **Over-engineering** | The AI complicates something that could be simple. Extremely common across all models. |
| 2 | **Reinventing the wheel** | It tries to build from scratch something that already exists as a library or framework. |
| 3 | **Knowledge cutoff gaps** | If you ask it to use a library released after its training cutoff, it will guess — and likely get it wrong. |
| 4 | **Code duplication** | It forgets it already created a component and creates another one. Now you maintain two instead of one. |
| 5 | **Poor separation of concerns** | It dumps code with different responsibilities into the same file, making maintenance a nightmare. |

**Root cause of all 5:** the context window.

---

## Understanding the Context Window

The context window is everything the model can "remember" in a session. It fills up with:

- File reads (command + full file contents returned)
- File writes
- Search results
- MCP responses (large JSON blobs)
- Your prompts
- The model's previous responses

**The rule:** the fuller the context window, the worse the output quality. Research consistently shows working within 40–50% of the context window produces significantly better results. Once you exceed that, clear and start fresh.

---

## The Golden Rule: Input Quality = Output Quality

> AI is a **multiplier**, not a transformer. It doesn't turn bad input into good output.

**What degrades input quality:**

| Problem | Example |
|---|---|
| Incorrect information | Pointing to the wrong file |
| Incomplete information | Missing the library's documentation |
| Useless information | Pasting irrelevant code that fills context |
| Too much information | Overloading the window before implementation begins |

**What you want instead:** feed the AI all necessary information to perform an implementation, in the most concise form possible. Leave the maximum context space free for the implementation itself.

---

## The SDD Workflow

Three phases, each ending with a `/clear` to reset the context window before the next phase.

```
Research → /clear → Spec → /clear → Code
   ↓                  ↓               ↓
 PRD.md            Spec.md       Implementation
```

---

### Phase 1 — Research

**Goal:** gather all the information the model will need, without implementing anything yet.

**Prompt the model to:**
1. Identify which files in the codebase will be affected
2. Find existing implementation patterns for similar features already in the project
3. Search the internet for documentation of the relevant technologies
4. Bring in external implementation patterns (Stack Overflow, GitHub repos, official docs)

**Pro tip — import reference repos:**
If you need to implement a pattern you haven't seen before, clone a GitHub repo that does it well into a `.temp/` folder, ask the model to study it, then delete the folder. This gives the model a concrete, proven reference without you needing to evaluate the quality yourself.

> Always prefer documented, proven patterns. Don't reinvent the wheel, and don't ask the model to either.

**Output:** a `PRD.md` file containing:
- Relevant codebase files (only the relevant ones — not the whole project)
- Key excerpts from library/framework documentation
- Code snippets showing implementation patterns (from your codebase, Stack Overflow, docs, or reference repos)

**Then:** run `/clear` — wipe the context window completely before moving to Phase 2.

---

### Phase 2 — Spec (Planning)

**Goal:** produce a precise, tactical implementation plan with zero ambiguity.

Start a brand-new conversation. Reference only the `PRD.md` from Phase 1:

```
Read PRD.md and generate a spec for me.
```

**The spec must be file-centric and explicit:**

```
File: src/features/auth/email-confirmation.service.ts
Action: CREATE
What to do:
  - Implement sendConfirmationEmail(userId: string): Promise<void>
  - Use the Resend client already configured in src/lib/resend.ts
  - Email template follows the pattern in PRD.md snippet #3
  - Token generation: use crypto.randomUUID(), store in user_tokens table
```

Every entry in the spec must specify:
- **Path** of the file (exact)
- **Action**: CREATE or MODIFY
- **What to do** in that file (detailed, unambiguous)
- **Code snippets** where relevant (from the PRD research)

> If the spec is vague, the model will make its own decisions — and you will likely not like the result.

**Output:** a `Spec.md` file — the complete implementation blueprint.

**Then:** run `/clear` again before Phase 3.

---

### Phase 3 — Code (Implementation)

**Goal:** execute the spec with the maximum context window available for implementation.

Start a brand-new conversation. Attach only the `Spec.md`:

```
Implement this Spec.md
```

That's it. The spec IS the prompt. By clearing context twice before this point, you have left the model the maximum possible working memory to implement correctly.

> **Never combine phases in a single conversation.** Research + Planning + Implementation in one chat = context overload = degraded output.

---

## Expected Results

When you apply SDD consistently, you will observe:

| Result | Why it happens |
|---|---|
| **Less duplicated code** | Research reveals existing components → spec says to import, not rewrite |
| **Simpler implementations** | Proven patterns from research are inherently more concise |
| **Higher first-shot accuracy** | Correct documentation in the spec → model uses the right API |
| **Better modularity** | Spec dictates exactly which files to create/modify → no dumping everything together |
| **Less technical debt** | Smaller, simpler, correct code is far cheaper to maintain |

> A great developer doesn't write more code — they write the same functionality in 100 lines instead of 2000. SDD nudges AI toward the 100-line version.

---

## SDD Artifact Conventions

| Artifact | Purpose | When to delete |
|---|---|---|
| `PRD.md` | Research summary — documentation excerpts, relevant files, code patterns | After Spec.md is generated and reviewed |
| `Spec.md` | Implementation blueprint — file list, actions, snippets | After implementation is complete and verified |
| `.temp/` | Temporary reference repos cloned for pattern study | Immediately after Research phase |

> Keep PRD.md and Spec.md in version control during the feature branch. They are the documented rationale for the implementation decisions.

---

## Quick Reference

```
Phase 1 — RESEARCH
  Prompt: "Research <feature>. Find affected files, existing patterns,
           library docs, and external implementation references."
  Output: PRD.md
  End:    /clear

Phase 2 — SPEC
  Prompt: "Read PRD.md and generate a spec."
  Output: Spec.md  (file path + action + what to do, per file)
  End:    /clear

Phase 3 — CODE
  Prompt: "Implement this Spec.md"  [attach Spec.md]
  Output: Implementation
  End:    Review, test, commit
```

---

## Context Window Health Rules

- Work within **40–50% of the context window** maximum per session
- When context is getting full mid-implementation: commit what works, `/clear`, continue from Spec
- Never re-read files you don't need — every token counts
- MCP tool responses are expensive — only invoke MCPs when the result goes into PRD or Spec

---

## Relationship to SPDD

SDD and SPDD address the same root problem from different angles:

| | SDD | SPDD |
|---|---|---|
| **Focus** | Context window efficiency | Governed, versioned prompt artifacts |
| **Audience** | Individual developer / solo builder | Teams requiring traceability and auditability |
| **Artifacts** | PRD.md + Spec.md (transient) | REASONS Canvas (permanent, synced with code) |
| **Sync discipline** | Clear and restart between phases | `/spdd-prompt-update` and `/spdd-sync` commands |
| **Best fit** | Fast feature delivery, solo or small team | Multi-developer, compliance-heavy, long-lived systems |

They are **complementary**: SDD's Research phase maps directly to SPDD's `/spdd-analysis`, and SDD's Spec maps to SPDD's REASONS Canvas Operations section. Teams can use SDD for speed and SPDD for governance on the same project.
