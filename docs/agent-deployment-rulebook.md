# Agent Deployment Rulebook

## Purpose

This document defines a practical operating model for deploying AI agents inside an organization.

The goal is not broad "AI adoption" for its own sake. Personal productivity tools are useful, but the larger opportunity is to automate important business workflows correctly, safely, measurably, and iteratively.

The central principle:

> **Agents should graduate from experiment → workflow → controlled production system.**

The unit of deployment is the **workflow**, not the employee.

---

## 1. Automate Workflows, Not People

Do not begin with:

- How can every employee use AI?
- How many Copilot or ChatGPT seats are active?
- How many prompts did people run?
- How many small agents can we launch?

Begin with:

- What recurring workflow has meaningful volume, cost, delay, friction, or error?
- What does "correct" look like?
- What systems, data, and actions does the workflow touch?
- Where should human judgment remain?
- What measurable business outcome should improve?

### Example

Weak framing:

```text
Give 500 employees a chatbot.
```

Better framing:

```text
Support ticket
  ↓
classify
  ↓
retrieve customer/context
  ↓
recommend action
  ↓
execute or route
  ↓
record outcome
```

A deployed agent should own a meaningful slice of a business process, not merely provide another interface for ad hoc prompting.

---

## 2. Personal Productivity Is Level 0

Personal AI remains useful for:

- drafting
- summarizing
- brainstorming
- research
- coding assistance
- meeting preparation
- document analysis

But this should not be confused with enterprise agent deployment.

### Agent Maturity Ladder

#### Level 0 — Personal AI
A human manually operates AI for individual productivity.

#### Level 1 — Assisted Workflow
AI performs a defined task or step. A human reviews or approves the result.

#### Level 2 — Agentic Workflow
An agent completes multiple steps using tools, APIs, data, and defined permissions.

#### Level 3 — Autonomous Workflow
The agent can execute routine actions automatically within policy and escalate exceptions.

#### Level 4 — Agent Operating System
Multiple agents and workflows share common:

- identity
- signals/events
- memory
- governance
- permissions
- observability
- routing
- execution controls

Meaningful enterprise leverage generally begins when organizations move beyond Level 0 and Level 1 into repeatable Level 2+ workflows.

---

## 3. Every Production Agent Needs a Champion

Every deployed workflow should have one named **Workflow Champion**.

The champion should be someone who deeply understands the operating process and remains accountable after the builders leave.

The champion owns:

- what gets built
- what "good" means
- edge cases
- failure modes
- escalation rules
- policy interpretation
- business consequences
- acceptance of new versions

Engineering owns implementation.

The Workflow Champion owns operational correctness.

The champion may be:

- an operations manager
- an analyst
- a domain expert
- a senior functional leader
- an internal technical operator
- a founder or executive with deep process knowledge

The critical characteristic is not title. It is trusted knowledge of the workflow.

---

## 4. No Agent Without a Definition of Correct

Before implementation, create an explicit acceptance contract.

Example:

```md
## Workflow
Support ticket triage

## Correct behavior
- Identify customer/account
- Classify issue into approved taxonomy
- Retrieve relevant account history
- Recommend correct routing
- Provide evidence for recommendation

## Must never
- Modify customer data
- Promise refunds
- Close tickets autonomously

## Escalate when
- confidence < threshold
- account cannot be matched
- financial issue detected
- policy conflict exists
```

The specification should live next to the code and evolve with it.

A useful rule:

> **If we cannot define correctness, we are not ready to automate the workflow.**

---

## 5. GitHub Is the Laboratory

Important agents should be treated as versioned software systems, not disposable prompts.

A suggested structure:

```text
/agents
  /support-triage
    README.md
    workflow.md
    policy.md
    agent.yaml
    CHANGELOG.md
    /evals
    /prompts
    /tools
```

The repository should preserve:

- workflow specification
- current production implementation
- prompts/system instructions
- tool definitions
- policies and permissions
- evaluation datasets
- test results
- changelog
- deployment history

This creates institutional memory and makes the agent inspectable by both humans and future agents.

---

## 6. Use a Champion / Challenger Model

Every important production agent should have a **Champion** and one or more **Challengers**.

### Champion

The currently approved production version.

### Challenger

An experimental candidate attempting to outperform the champion.

Examples of challenger changes:

- new model
- new prompt
- new reasoning strategy
- new retrieval architecture
- different tool sequence
- better context assembly
- lower-cost model routing
- stronger guardrails

Do not casually mutate the production agent.

Challenge it.

### Example Scorecard

```text
Champion v1.7
Accuracy:        92%
Cost/task:       $0.18
Escalation:      14%
Median latency:  4.2s

Challenger v1.8
Accuracy:        95%
Cost/task:       $0.15
Escalation:      11%
Median latency:  3.8s
```

A challenger should be promoted only after it meets the defined deployment criteria.

This changes the organizational mindset from:

> "Claude seems better today."

to:

> "We improved the workflow."

---

## 7. Separate Capability From Authority

An agent may be technically capable of taking an action without being permitted to take it.

These must be separate systems.

### Capability Layer

Responsible for:

- reasoning
- planning
- retrieval
- memory
- tool selection
- recommendation generation

### Authority / Governance Layer

Responsible for:

- tool permissions
- data access
- spending limits
- communication rights
- approval requirements
- rate limits
- role-based restrictions
- policy enforcement
- revocation
- shutdown

The agent can propose an action.

The governance layer determines whether that action is allowed.

This avoids embedding security and policy logic independently inside every agent.

---

## 8. Treat Every Agent Action as a Governed Event

Agent activity should emit structured signals/events that can be governed independently of the model.

Example:

```json
{
  "actor": "support-agent",
  "intent": "issue_refund",
  "customer": "12345",
  "amount": 74.00,
  "confidence": 0.94,
  "reason": "...",
  "evidence": []
}
```

A governance layer can then determine:

```text
ALLOW
DENY
REQUIRE_APPROVAL
ROUTE
RATE_LIMIT
LOG
```

This event-driven pattern provides a common control surface across many agents and SaaS tools.

It also creates a natural separation between:

- intelligence
- policy
- execution

---

## 9. Start Read-Only and Expand Authority Gradually

A useful deployment progression:

```text
OBSERVE
  ↓
RECOMMEND
  ↓
HUMAN APPROVAL
  ↓
LIMITED EXECUTION
  ↓
AUTONOMOUS ROUTINE EXECUTION
```

Example:

### Stage 1
Agent analyzes support tickets without affecting production.

### Stage 2
Agent recommends routing decisions.

### Stage 3
Agent routes tickets after human approval.

### Stage 4
Agent automatically routes normal cases.

### Stage 5
Agent completes routine resolution while escalating exceptions.

Authority should expand only after evidence accumulates.

---

## 10. Measure Workflow Outcomes, Not AI Activity

Weak metrics:

- monthly active AI users
- number of prompts
- number of agents created
- number of employees trained
- number of experiments launched

Useful metrics:

- task completion rate
- first-pass accuracy
- human intervention rate
- exception rate
- escalation rate
- time-to-resolution
- cost per completed workflow
- latency
- rollback rate
- customer outcome
- revenue created
- cost removed
- throughput gained

Usage is telemetry.

**Outcome is ROI.**

---

## 11. Use Sandboxes to Discover Builders and Workflows

Organizations should provide safe experimentation environments for employees who want to explore.

A useful sandbox may include:

- approved models
- synthetic or read-only data
- token budgets
- GitHub repositories/templates
- approved MCP servers/tools
- test APIs
- logging
- example agents
- deployment guidelines

But the sandbox should have a purpose.

Its goal is not to maximize random experimentation.

Its goal is to discover:

1. promising workflows
2. capable internal builders
3. future Workflow Champions
4. challengers worthy of formal evaluation

The best experiments should have a clear path into the production lifecycle.

---

## 12. Build Fewer, Deeper Agents

A useful operating rule:

> **One agent that owns 80% of an important workflow beats twenty surface-level demos.**

Organizations are naturally tempted to create separate:

- email agents
- meeting agents
- research agents
- CRM agents
- reporting agents
- document agents

Instead ask:

> What complete business outcome can we automate?

Example:

```text
Inbound lead
  ↓
enrichment
  ↓
qualification
  ↓
CRM research
  ↓
recommended response
  ↓
rep approval
  ↓
send
  ↓
CRM update
  ↓
follow-up scheduling
```

A coherent workflow compounds value because each step feeds the next.

---

# Production Deployment Gates

Every production agent should pass seven gates.

| Gate | Required Question |
|---|---|
| **Owner** | Who owns the workflow? |
| **Definition** | What exactly constitutes correct? |
| **Evaluation** | Can correctness be tested objectively? |
| **Authority** | What is the agent allowed to do? |
| **Observability** | Can every action be reconstructed? |
| **Escalation** | When must humans intervene? |
| **Rollback** | Can we instantly disable or revert it? |

A simple standard:

> **No seven gates, no production deployment.**

---

# Champion / Challenger Deployment Lifecycle

Recommended lifecycle:

```text
IDEA
  ↓
SANDBOX
  ↓
WORKFLOW SPEC
  ↓
CHALLENGER
  ↓
OFFLINE EVAL
  ↓
SHADOW MODE
  ↓
LIMITED TRAFFIC
  ↓
CHAMPION
  ↓
CONTINUOUS CHALLENGERS
```

The key concept:

> **Champion does not mean permanent.**

The champion is simply the best verified production implementation so far.

---

# Suggested Promotion Criteria

A challenger should not be promoted based on subjective enthusiasm.

Promotion should use an agreed scorecard.

Possible dimensions:

| Dimension | Example |
|---|---|
| Accuracy | Meets or exceeds champion |
| Safety | No material increase in policy violations |
| Cost | At or below acceptable cost/task |
| Latency | Meets workflow requirement |
| Escalation | Improves or stays within target |
| Reliability | Handles expected failure conditions |
| Observability | Emits required logs/events |
| Authority | Cannot exceed assigned permission scope |
| Business outcome | Improves the KPI the workflow exists to influence |

A challenger does not have to win on every metric.

It must beat the champion on the weighted criteria established by the Workflow Champion.

---

# Repository as Organizational Memory

The agent repository should be readable by both humans and AI coding agents.

Recommended artifacts:

```text
workflow.md       What business workflow exists and why
policy.md         Constraints, permissions, escalation rules
evals/            Test cases and expected outcomes
agent.yaml        Model/tool/runtime configuration
prompts/          Versioned prompts
tools/            Tool or MCP definitions
README.md         How the system works
CHANGELOG.md      What changed and why
```

The repository becomes the canonical record of:

- how the workflow works
- why decisions were made
- what the agent is allowed to do
- how correctness is tested
- what version is in production
- what challengers are being evaluated

---

# Operating Principle: Humans Define "Good"

The strongest AI deployments pair technical builders with people who understand the business process deeply.

AI can optimize against a target.

The organization still has to define the target.

The Workflow Champion should therefore remain accountable for:

- the definition of correct
- acceptance tests
- exception policy
- promotion criteria
- production approval

This is particularly important when tacit operational knowledge is not fully documented.

The deployment process should convert that tacit knowledge into explicit workflow rules and evals.

---

# Enterprise Architecture Implication

At sufficient scale, agent deployment naturally separates into three layers.

## 1. Build / Intelligence Layer

Where agents are created and improved.

Typical components:

- GitHub
- coding agents
- prompts
- models
- RAG
- memory
- eval suites
- harnesses
- MCP/tool clients

## 2. Governance / Authority Layer

Where policy determines what agents may do.

Typical capabilities:

- identity
- permissions
- tool authorization
- scoped credentials
- approval intercepts
- throttling
- budget controls
- revocation
- shutdown

## 3. Signals / Execution Layer

Where proposed and completed actions move through the organization.

Typical capabilities:

- structured events
- triggers
- routing
- queues
- approvals
- audit logs
- execution
- status
- telemetry

This separation lets organizations improve intelligence independently from authority and execution.

---

# The Five Rules

If the full framework needs to be reduced to five rules:

> **1. Automate workflows, not employees.**

> **2. A workflow must have an owner and a definition of correct.**

> **3. Capability and authority are separate systems.**

> **4. Production agents are champions; improvements compete as challengers.**

> **5. Measure completed business outcomes, not AI activity.**

---

# Short Version

A serious agent program should operate more like software deployment than an AI training initiative.

Teams should:

1. identify high-value workflows
2. appoint domain champions
3. explicitly define correctness
4. build versioned agents in GitHub
5. evaluate challengers against a production champion
6. separate agent capability from execution authority
7. emit every action as a governable event
8. start read-only and expand permissions gradually
9. measure business outcomes
10. continuously improve deployed workflows

The goal is not to create the largest number of agents.

The goal is to create a small number of trustworthy agents that own increasingly valuable portions of real work.
