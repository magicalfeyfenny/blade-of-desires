# Blade of Desires

Blade of Desires is a vertical 2D shmup built in GameMaker, with perspective
3D used for presentation rather than gameplay authority. The canonical product
contract and stable identifiers live in
[content/product_contract.json](content/product_contract.json), with a readable
guide in [docs/product-contract.md](docs/product-contract.md). Canonical emitter
pattern descriptors begin with
[content/patterns/neutral_v1.json](content/patterns/neutral_v1.json), with their
schema and normalization contract in
[docs/pattern-descriptors.md](docs/pattern-descriptors.md). Canonical neutral
stage and encounter schedules begin with
[content/stages/neutral_v1.json](content/stages/neutral_v1.json), with their
typed execution and ownership contract in
[docs/stage-schedules.md](docs/stage-schedules.md).

## Governance overview (non-normative)

This README is navigation, not a source of repository rules. The authoritative
workflow and rationale live in [GOVERNANCE.md](GOVERNANCE.md#authority), while
[PROJECT_POLICY.toml](PROJECT_POLICY.toml) owns executable paths, formats,
limits, and risk patterns.

Normal agent-governed work starts with one coherent implementation issue.
Broader requests split only when they contain independently meaningful
outcomes; technical implementation layers stay together when they jointly
deliver one outcome. Each issue branches from current `origin/dev`, uses an
issue-numbered branch, and opens a draft pull request after the first
meaningful, tested milestone. Blocked work waits until its blockers are
resolved.

Validation happens in three stages: focused checks support each milestone, the
complete change receives whole-issue local validation, and hosted CI then
verifies the exact pull-request head, body, and labels. Completion metadata is
added only after the whole change is locally valid.

Risk determines the final path. After whole-issue Stage 2 evidence, governed
changes complete bounded adversarial review and adjudication before adding
completion metadata. Eligible completed low- or medium-risk work targeting
`dev` can be marked ready and squash-merged by repository automation after its
final hosted evidence passes; medium-risk work also needs focused,
change-specific machine-verifiable evidence. High-risk or manually handled
work remains a draft for human review, readiness, and merge. High risk is
reserved for concrete structural or operational danger, including configured
authority-bearing paths and exceptional structural size; ordinary game code,
content, project metadata, and assets can be low or medium according to their
scope. Size, importance, difficulty, or breadth alone does not make work high
risk.

`main` is release-only, and releases require explicit human authorization.
Human-created work uses a separate protected lane that agents do not modify.

For engine and asset decisions, see
[Native GameMaker functionality](GOVERNANCE.md#native-gamemaker-functionality)
and [Derived assets](GOVERNANCE.md#derived-assets). Storage enforcement follows
[Candidate storage](GOVERNANCE.md#candidate-storage). The
[adoption guide](docs/ADOPTION.md) explains audits of existing repositories,
the [bounded policy-update procedure](docs/POLICY_UPDATE.md) explains how to
adopt a newer upstream revision, and the [CI guide](docs/CI.md) describes the
required checks and evidence.

## Start here

Choose the path that matches the repository before changing anything:

- A valid GameMaker project with no meaningful governance: run the
  [greenfield bootstrap](docs/SETUP.md).
- An existing repository with independent governance, earlier framework
  lineage, or uncertain history: use the read-only
  [brownfield adoption plan](docs/ADOPTION.md).
- A repository that already adopted this framework and needs a newer upstream
  policy: use the [bounded policy-update procedure](docs/POLICY_UPDATE.md).

The bootstrap detects the latter cases and stops before overwriting authority.
It discovers an existing GameMaker project instead of moving it into a
template-specific directory. Read [docs/SETUP.md](docs/SETUP.md) for commands,
verification, recovery, and the setup actions that remain human-owned.

## Day-to-day workflow

For day-to-day repository work, [AGENTS.md](AGENTS.md#authority-and-task-routing)
routes each task to only the governance sections and local skill it needs.
Normal agent-governed work starts with one coherent issue, branches from the
current `origin/dev`, and opens a draft pull request after its first tested
milestone. Focused checks support milestones, whole-issue local evidence comes
before completion metadata, and hosted CI verifies the exact pull-request
candidate. See [GOVERNANCE.md](GOVERNANCE.md#authority) for the authoritative
rules.

`dev` is the integration branch. `main` is release-only. High-risk and
human-created work stays at the human review, readiness, and merge gates;
release and publication actions always require explicit human authority.

Begin legacy, asset, or repository archaeology at
[docs/archaeology/README.md](docs/archaeology/README.md).
