# Agent Deployment Checklist

Use this checklist before promoting any agent or agentic workflow into production.

## Workflow

- [ ] The workflow is clearly defined.
- [ ] The workflow has meaningful business value.
- [ ] The agent owns a workflow or coherent workflow segment, not merely a generic productivity task.
- [ ] Inputs, outputs, systems, and downstream actions are documented.

## Champion

- [ ] A named Workflow Champion exists.
- [ ] The champion understands what correct and incorrect outcomes look like.
- [ ] The champion owns acceptance criteria and production approval.
- [ ] Escalation ownership is defined.

## Definition of Correct

- [ ] Correct behavior is documented.
- [ ] Failure conditions are documented.
- [ ] "Must never" actions are documented.
- [ ] Human escalation conditions are documented.
- [ ] Edge cases are represented in evals where practical.

## Evaluation

- [ ] A repeatable eval suite exists.
- [ ] The current production Champion has a baseline score.
- [ ] Challenger performance is measured against the Champion.
- [ ] Accuracy, cost, latency, escalation, and business outcomes are considered.
- [ ] Promotion thresholds are agreed before production rollout.

## Authority

- [ ] Tool access is explicitly scoped.
- [ ] Data permissions are explicitly scoped.
- [ ] Financial or communication authority is explicitly limited.
- [ ] High-risk actions require approval.
- [ ] Credentials can be revoked independently of the agent.
- [ ] Agent capability is separated from execution authority.

## Deployment Progression

- [ ] Sandbox testing completed.
- [ ] Offline eval completed.
- [ ] Shadow mode completed where applicable.
- [ ] Limited-traffic deployment completed where applicable.
- [ ] Authority has expanded gradually: Observe → Recommend → Approve → Execute.
- [ ] Production Champion is identified and versioned.

## Observability

- [ ] Every important action emits a structured event/log.
- [ ] Decisions can be reconstructed after the fact.
- [ ] Inputs, model/version, tools used, outputs, and final actions are traceable.
- [ ] Business outcome telemetry exists.
- [ ] Cost and latency are measurable.

## Governance

- [ ] Proposed actions can be ALLOW / DENY / REQUIRE_APPROVAL / ROUTE / RATE_LIMIT / LOG.
- [ ] Policies are enforced outside the model where practical.
- [ ] Approval paths are defined.
- [ ] Rate limits and budgets are defined.
- [ ] Global disable / kill switch exists for meaningful production actions.

## Rollback

- [ ] The agent can be disabled immediately.
- [ ] A previous Champion can be restored.
- [ ] Changes are versioned.
- [ ] Deployment history is recorded.

## Repository

Recommended minimum structure:

```text
/agents/<workflow>
  README.md
  workflow.md
  policy.md
  agent.yaml
  CHANGELOG.md
  /evals
  /prompts
  /tools
```

## Production Gate

An agent should not enter production unless all seven gates have clear answers:

1. **Owner** — Who owns the workflow?
2. **Definition** — What constitutes correct?
3. **Evaluation** — Can correctness be tested?
4. **Authority** — What may the agent do?
5. **Observability** — Can every important action be reconstructed?
6. **Escalation** — When must humans intervene?
7. **Rollback** — Can the system be disabled or reverted immediately?

> **No seven gates, no production deployment.**

## Champion / Challenger Lifecycle

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

## Five Rules

1. Automate workflows, not employees.
2. Every workflow needs an owner and definition of correct.
3. Separate capability from authority.
4. Treat production versions as Champions and improvements as Challengers.
5. Measure completed business outcomes, not AI activity.
