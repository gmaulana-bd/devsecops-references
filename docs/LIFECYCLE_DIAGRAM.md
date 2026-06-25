# DevSecOps Lifecycle Diagram

This is the picture that ties everything together. Same lifecycle as the AXA Secure SDLC training, shown as a working pipeline.

## The full lifecycle

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│   PLAN ──► CODE ──► BUILD ──► TEST ──► RELEASE ──► DEPLOY ──► OPERATE     │
│    │        │        │        │         │           │           │          │
│    └────────┴────────┴────────┴─────────┴───────────┴───────────┘          │
│                                                                            │
│                            ◄── Shift-Left ──                              │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
                                       ▲
                                       │
                                       └─── (feedback loop: monitoring + incidents
                                            feed into the next Plan cycle)
```

## What happens at each stage in this repo

```
┌─────────────┬─────────────────────┬─────────────────────────────────────────┐
│   STAGE     │  TOOL               │  AXA REQUIREMENT                        │
├─────────────┼─────────────────────┼─────────────────────────────────────────┤
│ Plan        │ (SRA, threat model) │ SSDLC-PLA-01, SSDLC-PLA-02             │
│             │ Iriusrisk           │ (manual activity, not in pipeline)      │
├─────────────┼─────────────────────┼─────────────────────────────────────────┤
│ Code        │ Pre-commit Gitleaks │ SSDLC-DEV-03                            │
│             │ IDE SAST plugin     │ SSDLC-DEV-01                            │
├─────────────┼─────────────────────┼─────────────────────────────────────────┤
│ Build       │ Maven compile       │ SSDLC-DEV-01                            │
│             │ Unit tests          │                                         │
├─────────────┼─────────────────────┼─────────────────────────────────────────┤
│ Test        │ SpotBugs+FindSecBugs│ SSDLC-TST-01 (SAST)                     │
│             │ OWASP Dep-Check     │ SSDLC-TST-01 (SCA)                      │
│             │ Server-side Gitleaks│ SSDLC-DEV-03                            │
│             │ CycloneDX           │ SSDLC-DEV-02 (SBOM)                     │
│             │ Docker build        │ CLDEV-CFG-01                            │
│             │ Trivy               │ SSDLC-TST-01 (container scan)           │
│             │ Checkov             │ CLDEV-TES-01 (IaC scan)                 │
│             │ OWASP ZAP           │ SSDLC-TST-02 (DAST)                     │
├─────────────┼─────────────────────┼─────────────────────────────────────────┤
│ Release     │ git tag, mvn deploy │ SemVer + SSDLC-DEV-02                   │
│             │ JFrog Artifactory   │ (artefact registry)                     │
├─────────────┼─────────────────────┼─────────────────────────────────────────┤
│ Deploy      │ GitHub Environments │ SSDLC-DEP-03 (4-eyes approval)          │
│             │ Terraform apply     │ CLDEV-CFG-03                            │
│             │ OIDC (no long-lived │ CLDEV-IAM-03                            │
│             │   credentials)      │                                         │
├─────────────┼─────────────────────┼─────────────────────────────────────────┤
│ Operate     │ Security Hub (CIS)  │ SSDLC-OPS-01                            │
│             │ CloudWatch metrics  │                                         │
│             │ SIEM (Splunk)       │                                         │
│             │ WAF (F5), RASP      │                                         │
│             │   (Contrast)        │                                         │
└─────────────┴─────────────────────┴─────────────────────────────────────────┘
                                        │
                                        ▼
                              ┌──────────────────┐
                              │  Loop back to    │
                              │  PLAN with new   │
                              │  findings, CVEs, │
                              │  threats         │
                              └──────────────────┘
```

## The Shift-Left principle, shown visually

The arrows below the lifecycle show that the SAME class of security finding can be caught at multiple stages. The further left it is caught, the cheaper it is to fix.

```
                Code-level secret leak
                ─────────────────────►
  caught in IDE       cost: 0
  caught at commit    cost: 0      (pre-commit hook)
  caught at CI        cost: low    (server-side scan)
  caught in DAST      cost: medium (after deploy to staging)
  caught in prod      cost: HIGH   (incident, customer notification)
  caught by attacker  cost: BREACH (DORA reporting, fines, reputation)
```

The goal of every gate is to catch findings as far LEFT as possible.

## How the 12 stages in this repo map to the lifecycle

```
Pre-commit  (Stage 1)  ────► CODE phase
Build       (Stage 2)  ────► BUILD phase
SAST        (Stage 3)  ────►
SCA         (Stage 4)  ────►
Secret scan (Stage 5)  ────► TEST phase
SBOM        (Stage 6)  ────►
Container   (Stage 7)  ────►
Trivy       (Stage 8)  ────►
Checkov     (Stage 9)  ────►
DAST        (Stage 10) ────►
Gate        (Stage 11) ────► DEPLOY phase
Post-deploy (Stage 12) ────► OPERATE phase
                                    │
                                    ▼
                              feedback to PLAN
```

## Why this lifecycle works

Three principles tie it all together:

**Defense in depth.** No single tool catches everything. Pre-commit catches secrets at developer machines. CI catches them again on push (defeats --no-verify). DAST catches runtime issues SAST cannot see. CIS audit catches misconfigurations. Each layer covers the gaps of the others.

**Automation, not policy.** AXA policy says "no Critical CVEs in production." The pipeline enforces that with code: `-DfailBuildOnCVSS=7`. The policy and the enforcement are the same artifact. Auditors can read the workflow YAML and see the rule.

**Continuous, not one-time.** Every push runs the full pipeline. Every deployment triggers Security Hub re-evaluation. CVEs published after release are detected on the next build. The loop never stops.
