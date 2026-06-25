# AXA DevSecOps Reference Repository

**A working example of the full DevSecOps lifecycle, implemented as real CI/CD workflow code.**

This repository accompanies the AXA Secure SDLC training. It shows how every concept from the training course (SAST, SCA, secret scanning, SBOM, IaC scanning, container hardening, deployment gates) fits together in one working pipeline.

The application itself is intentionally trivial: a Spring Boot REST API with two endpoints. The point is not the application. The point is the pipeline around it.

## What you can do with this repo

1. **Read it** to see how the lifecycle fits together end to end
2. **Clone it** as a starting point for your own project
3. **Fork it** and push a commit to watch the pipeline run on your own GitHub
4. **Copy individual workflow steps** into your existing pipeline

## The full pipeline at a glance

```
Plan ─► Code ─► Build ─► Test ─► Release ─► Deploy ─► Operate
                                                              │
                                                              └──► (loop back to Plan)
```

Twelve stages run on every push or pull request. Each stage maps to a specific AXA SDLC requirement.

| # | Stage | Tool | AXA Reference |
|---|---|---|---|
| 1 | Pre-commit hook (secret scan) | Gitleaks | SSDLC-DEV-03 |
| 2 | Build | Maven | SSDLC-DEV-01 |
| 3 | SAST | SpotBugs + FindSecBugs | SSDLC-TST-01 |
| 4 | SCA | OWASP Dependency-Check | SSDLC-DEV-02, SSDLC-TST-01 |
| 5 | Secret scan in CI | Gitleaks | SSDLC-DEV-03 |
| 6 | SBOM generation | CycloneDX | SSDLC-DEV-02 |
| 7 | Container build | Docker (distroless base) | CLDEV-CFG-01 |
| 8 | Container scan | Trivy | CLDEV-CFG-01, SSDLC-TST-01 |
| 9 | IaC scan | Checkov | CLDEV-TES-01, CIS AWS v5.0.0 |
| 10 | DAST (staging) | OWASP ZAP baseline | SSDLC-TST-02 |
| 11 | Manual approval gate | GitHub Environments | SSDLC-DEP-03 |
| 12 | Post-deploy verification | Smoke test + Security Hub | SSDLC-OPS-01 |

## Repository layout

```
.
├── README.md                          (you are here)
├── docs/
│   ├── PIPELINE.md                    (line-by-line walkthrough of the workflow)
│   ├── LIFECYCLE_DIAGRAM.md           (the full lifecycle as an ASCII diagram)
│   └── HOW_TO_RUN.md                  (clone, push, watch it work)
├── .github/
│   └── workflows/
│       └── devsecops.yml              (the main pipeline, 12 stages)
├── .pre-commit-config.yaml            (local secret scanning before commit)
├── .gitleaks.toml                     (Gitleaks rule configuration)
├── pom.xml                            (Maven config with all security plugins)
├── src/
│   ├── main/java/com/axa/demo/
│   │   ├── DemoApplication.java       (Spring Boot entry point)
│   │   └── ApiController.java         (two trivial REST endpoints)
│   ├── main/resources/
│   │   └── application.properties     (uses ${ENV_VAR}, no hardcoded secrets)
│   └── test/java/com/axa/demo/
│       └── ApiControllerTest.java     (basic unit test so build is realistic)
├── Dockerfile                         (distroless base, non-root user)
├── k8s/
│   └── deployment.yaml                (readOnlyRootFilesystem, securityContext)
├── terraform/
│   └── main.tf                        (CIS-compliant S3, RDS, KMS)
├── CODEOWNERS                         (Security Champion required on workflow changes)
└── CHANGELOG.md                       (DORA audit trail)
```

## How to read this repo

If you have 5 minutes: read `docs/LIFECYCLE_DIAGRAM.md` and skim `.github/workflows/devsecops.yml`.

If you have 15 minutes: read `docs/PIPELINE.md` for the line-by-line explanation of every workflow stage.

If you have an hour: clone the repo, follow `docs/HOW_TO_RUN.md`, push a commit, watch the pipeline run on GitHub Actions.

## How this maps to the training

Each demo in the SDLC training corresponds to one or more stages in this pipeline:

| Training Demo | Pipeline Stages Covered |
|---|---|
| Demo 1 (Supply Chain + Library Lifecycle) | Stages 4, 6 (SCA + SBOM) |
| Demo 2 (Secret Detection) | Stages 1, 5 (pre-commit + CI scan) |
| Demo 3 (DAST) | Stage 10 (ZAP baseline) |
| Demo 4 (Security Pipeline) | Stages 3, 4, 5 in parallel |
| Demo 5 (Gitflow Release) | Stages 6, 11, 12 (SBOM, gate, post-deploy) |
| Demo 6 (Pipeline Pollution) | The hardening this entire workflow uses |
| Demo 7 (IaC + Container) | Stages 7, 8, 9 (Docker, Trivy, Checkov) |
| Demo 8 (CIS Audit) | Stage 12 (Security Hub check) |

In other words: every demo in the training shows ONE piece of this lifecycle. This repo shows them all wired together.

## Important notes

**This is a training reference, not production code.** The application is trivial on purpose. The pipeline is the lesson.

**Some stages require external setup to actually run.** DAST needs a staging environment. Security Hub needs an AWS account. Where this matters, the workflow has clear notes and continues even if the integration is missing, so you can read the workflow without standing up infrastructure.

**Tool choices reflect AXA approved tools where applicable.** The pipeline uses free or open-source equivalents (Gitleaks, SpotBugs, OWASP Dep-Check, Trivy, Checkov, ZAP) so anyone can run it. In production, AXA teams use Checkmarx, Mend.io, Qualys, Aqua, Contrast.

## Next steps

1. Read `docs/PIPELINE.md` to understand each stage
2. Try the local pre-commit hook: `pre-commit install`, then commit a file with a fake AWS key and watch it get blocked
3. Fork the repo and push to GitHub to see the full pipeline run
4. Take any single workflow step and add it to your own repository

Questions or issues: contact your Security Champion or post in the [Slack or Teams channel].
