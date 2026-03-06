# dev-loop

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/dev-loop)](https://www.powershellgallery.com/packages/dev-loop)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/dev-loop)](https://www.powershellgallery.com/packages/dev-loop)
[![License](https://img.shields.io/github/license/markgar/dev-loop)](LICENSE)

Automated development loop powered by [GitHub Copilot CLI](https://docs.github.com/en/copilot). Each phase shells out to `copilot -p "..." --yolo` with a crafted prompt. Specs are numbered Markdown files (`NN-slug.md`) processed one at a time — plan, build, review, and test — all phases to completion before moving to the next.

## Requirements

- [GitHub Copilot CLI](https://docs.github.com/en/copilot) (`copilot` on `$env:PATH`)
- PowerShell 7+
- Git
- The target project directory must be a git repository (`git init`)

## Install

### From PowerShell Gallery

```powershell
Install-Module -Name dev-loop
```

### From Source

```powershell
git clone https://github.com/markgar/dev-loop.git
```

## Usage

### As a module (installed from Gallery)

```powershell
Invoke-DevLoop -SpecsDir <path> -ProjectDir <path> [-GitPush]
```

### As a script (cloned from repo)

```powershell
.\dev-loop.ps1 -SpecsDir <path> -ProjectDir <path> [-GitPush]
```

### Quick Start with Sample Specs

The repo includes sample specs in [spec-kit](https://github.com/github/spec-kit) style — a `CONSTITUTION.md` and two numbered specs that describe a bookstore REST API:

- `CONSTITUTION.md` — Product constraints (tech stack, conventions, principles)
- `01-bookstore-rest-api.md` — Core CRUD endpoints for a bookstore API
- `02-book-search-filtering.md` — Search and filtering capabilities

```powershell
mkdir ~/my-bookstore
cd ~/my-bookstore
git init

# Point dev-loop at the sample specs
<path-to-dev-loop>/dev-loop.ps1 -SpecsDir <path-to-dev-loop>/sample-spec -ProjectDir .
```

The dev-loop will plan, build, review, and test each spec in order — generating the entire project from scratch in your target directory.

## How It Works

```
Invoke-DevLoop -SpecsDir <path> -ProjectDir <path> [-GitPush]
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

A `CONSTITUTION.md` at the specs root defines product constraints included in every prompt.

### Tracking

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

## Project Structure

```
dev-loop/
  dev-loop.ps1              # Thin launcher (clone-and-run convenience)
  README.md
  sample-spec/              # Sample specs (not published to Gallery)
  src/
    dev-loop/               # PowerShell module (published to Gallery)
      dev-loop.psd1         # Module manifest
      dev-loop.psm1         # Module implementation (Invoke-DevLoop)
      agents/               # Phase scripts
```

## Contributing

Contributions are welcome! Please open an issue to discuss a change before submitting a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
