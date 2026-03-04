# dev-loop

Automated development loop powered by [GitHub Copilot CLI](https://docs.github.com/en/copilot). Each phase shells out to `copilot -p "..." --yolo` with a crafted prompt.

## How It Works

```
.\dev-loop.ps1 -SpecsDir <path>
    │
    ├── preflight.ps1  — Discover specs, constitution review
    │
    └── Per-spec loop:
        ├── plan.ps1       — Decompose spec into commit-sized tasks
        ├── plan-eval.ps1  — Review & fix the plan in-place
        ├── build.ps1      — Build next unchecked task (loops until plan complete)
        ├── review.ps1     — Senior SWE code review + standards capture
        └── test.ps1       — Write/run tests, validate against spec
```

Specs are numbered Markdown files (`NN-slug.md`) in the specs directory. A `CONSTITUTION.md` at the specs root defines product constraints included in every prompt. The loop processes one spec at a time, all phases to completion, before moving to the next.

## Tracking

Each run creates a timestamped directory under `.dev-loop/` in the target project:

```
.dev-loop/
└── 20260304-183305/
    ├── dev-loop.log              # Orchestrator summary
    ├── preflight.log             # Spec discovery + constitution check
    ├── 01-my-feature.log         # All phases for this spec
    ├── manifest.json             # Per-spec phase timestamps
    ├── spec-discovery.json       # Discovered specs
    ├── plan-01-my-feature.md     # Task checklist for spec 01
    └── preflight-findings.md     # (only if constitution has issues)
```

Phase timestamps in `manifest.json` enable checkpoint/resume — completed phases are skipped on re-run.

## Requirements

- [GitHub Copilot CLI](https://docs.github.com/en/copilot) (`copilot` on `$env:PATH`)
- PowerShell 7+
- Git
