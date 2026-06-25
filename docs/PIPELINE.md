# Pipeline Walkthrough

Line by line, what every stage in `.github/workflows/devsecops.yml` does, why it is there, and which AXA control it implements.

If you have read the workflow file already, this document is the explanation. If you have not, read the workflow file alongside this document.

## Pipeline-level settings

```yaml
permissions:
  contents: read
  pull-requests: read
  security-events: write
```

GitHub Actions default permissions are too generous. By default, `GITHUB_TOKEN` has write access to almost everything. This block restricts it to the minimum the pipeline needs. Mapping to OWASP CI/CD Top 10 Risk 5 (Insufficient PBAC).

The training Demo 6 (Pipeline Pollution) showed why this matters. A malicious action that runs with default permissions can write to repository contents, create releases, modify issues, and more. With explicit minimum permissions, the blast radius of any compromised action is small.

## Stage 1: Pre-commit (client side, not in YAML)

This stage runs on the developer's laptop before any code reaches GitHub.

```bash
pip install pre-commit
pre-commit install
```

After running these once, every `git commit` triggers `.pre-commit-config.yaml`. Gitleaks scans the staged files. If a secret is detected, the commit is blocked with a clear error message.

Stage 5 below re-runs Gitleaks server-side, in case a developer bypassed the local hook with `git commit --no-verify`. Defense in depth.

AXA mapping: SSDLC-DEV-03.

## Stage 2: Build

```yaml
- name: Compile
  run: mvn -B compile

- name: Unit tests
  run: mvn -B test
```

Compiles the application and runs unit tests. This stage fails fast on compilation errors, before any expensive security scans run. If the code does not compile, no point scanning it.

Note `-B` (batch mode): suppresses Maven's interactive prompts, which are useless in CI and slow down log output.

AXA mapping: SSDLC-DEV-01.

## Stage 3: SAST (SpotBugs with FindSecBugs)

```yaml
- name: Run SpotBugs with FindSecBugs
  run: mvn -B spotbugs:check
```

SpotBugs analyses the compiled bytecode for bug patterns. FindSecBugs adds security-specific detectors: SQL injection, command injection, weak cryptography, hardcoded passwords, insecure deserialization, and more. Around 130 security checks total.

The configuration in `pom.xml` sets `failOnError: true` and `threshold: Low`, so any finding fails the build. In production, teams typically tune this to fail only on `High` and `Critical` while still reporting `Medium` and `Low` for review.

AXA mapping: SSDLC-TST-01.

## Stage 4: SCA (OWASP Dependency-Check)

```yaml
- name: Run OWASP Dependency-Check
  run: mvn -B org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7
```

Scans every dependency (direct and transitive) against the NVD CVE database. `failBuildOnCVSS=7` fails the build on any finding with CVSS 7.0 or higher, which is the threshold for AXA Critical and High.

The NVD database download is cached between runs (the `actions/cache` step) because downloading 200MB of CVE data on every build is wasteful and rate-limited.

This is the gate that would have caught Log4Shell. The 2.14.x versions of `log4j-core` would be flagged the moment CVE-2021-44228 was published to NVD. The patched 2.17.x would pass.

AXA mapping: SSDLC-DEV-02 (SCA mandatory), SSDLC-TST-01 (gate in CI/CD).

## Stage 5: Secret scan (server-side)

```yaml
- uses: gitleaks/gitleaks-action@cb7149b9b57195b609bba6b22fd6e1e1f2780211
```

Re-runs Gitleaks on the full git history (`fetch-depth: 0`). Catches:
- Developers who bypassed the local pre-commit hook with `--no-verify`
- Secrets that were committed before the pre-commit hook was installed
- Secrets in branches that never had the hook configured

Action is pinned to a specific commit SHA, not a tag like `@v2`. Pinning to tags is OWASP CI/CD Top 10 Risk 3 (Dependency Chain Abuse). Tags can be moved. SHAs cannot.

AXA mapping: SSDLC-DEV-03, CLDEV-IAM-02.

## Stage 6: SBOM (CycloneDX)

```yaml
- name: Generate SBOM (CycloneDX)
  run: mvn -B org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom
```

Generates `target/bom.json`: a complete inventory of every component in the build, including transitive dependencies, versions, and licenses. CycloneDX is the OWASP-standardized format.

The SBOM is uploaded as a workflow artifact. In a release workflow, the SBOM would also be committed to the repository (so it is in git history for audit) and attached to the GitHub Release.

Why this matters: when the next Log4Shell happens, your security team asks "are we affected?" With an SBOM, you grep `bom.json`. Without one, you spend days inventorying. AXA SSDLC-DEV-02 makes SBOM mandatory.

AXA mapping: SSDLC-DEV-02.

## Stage 7: Container build

```yaml
- name: Build container image
  run: docker build -t ${IMAGE_NAME}:${{ github.sha }} .
```

Builds the Docker image using the multi-stage Dockerfile. The Dockerfile uses:
- `eclipse-temurin:17-jdk-alpine` as the build stage (full JDK + Maven)
- `gcr.io/distroless/java17-debian12:nonroot` as the runtime stage

Distroless images contain only the JVM and the application. No shell, no package manager, no curl, no useful tools for an attacker who manages to get code execution. Smallest attack surface possible.

AXA mapping: CLDEV-CFG-01.

## Stage 8: Container scan (Trivy)

```yaml
- uses: aquasecurity/trivy-action@b2933f565dbc598b29947660e66259e3c7bc8561
  with:
    severity: 'CRITICAL,HIGH'
    exit-code: '1'
```

Trivy scans the built image for:
- OS-level CVEs (in the distroless base layers)
- Java library CVEs (catches what Dep-Check missed, like libraries pulled in via the base image)
- Container misconfigurations (running as root, no USER directive, etc.)

Fails the build on any Critical or High. SARIF output is uploaded to GitHub Security tab so findings appear in the repository's Security dashboard.

AXA mapping: CLDEV-CFG-01, SSDLC-TST-01.

## Stage 9: IaC scan (Checkov)

```yaml
- uses: bridgecrewio/checkov-action@7ac718e5e3735ff5bcc9fdf75ffbeb1f78751cfc
  with:
    framework: terraform,kubernetes,dockerfile
```

Scans every Terraform file (`terraform/main.tf`), every Kubernetes manifest (`k8s/deployment.yaml`), and the Dockerfile for security misconfigurations.

Checkov maps directly to CIS AWS controls. Each finding includes the Checkov check ID (e.g. `CKV_AWS_53`) AND the CIS control ID (e.g. `CIS S3.1`). The Terraform module in this repo is intentionally CIS-compliant, so Checkov passes cleanly. Modify it (e.g. remove the `aws_s3_bucket_public_access_block` resource) and Checkov fails.

AXA mapping: CLDEV-TES-01, CIS AWS v5.0.0.

## Stage 10: DAST (OWASP ZAP)

```yaml
- uses: zaproxy/action-baseline@a99feab3f0eba3c70d4cae5a900f95e09c5a3ab1
  with:
    target: 'https://staging.example.com'
```

ZAP baseline scan: runs the spider and passive analysis against a deployed staging environment. Catches runtime issues that SAST cannot see: missing security headers, insecure cookies, mixed content, etc.

This stage only runs on push to `develop` (after merge), not on every PR. Reason: DAST requires a running staging environment. Standing up staging per-PR is expensive and slow. Per-merge is the normal cadence.

For a real staging environment, replace `https://staging.example.com` with your actual URL and configure authenticated DAST with credentials in `secrets`.

AXA mapping: SSDLC-TST-02.

## Stage 11: Deploy (manual approval gate)

```yaml
deploy-production:
  environment:
    name: production
    url: https://prod.example.com
```

The `environment: production` line is the magic. In GitHub Settings → Environments, you configure the production environment with:
- Required reviewers (e.g. a Tech Lead and a Security Champion)
- Wait timer (e.g. 5 minutes for sober second thought)
- Deployment branches (only `main`)

When this job runs, GitHub pauses and notifies the required reviewers. The job does not proceed until a human approves. This is the 4-eyes principle in SSDLC-DEP-03, enforced by tooling.

The deployment itself uses OIDC (OpenID Connect) for cloud authentication. The pipeline does not store long-lived AWS credentials. Instead, GitHub issues a short-lived (15 minute) token that the cloud trusts because of a pre-configured trust relationship. CLDEV-IAM-03.

AXA mapping: SSDLC-DEP-03 (4-eyes), CLDEV-IAM-03 (short-lived tokens).

## Stage 12: Post-deploy verification

```yaml
post-deploy:
  needs: deploy-production
```

After the deployment succeeds, this stage verifies the deployed state:
- Trigger AWS Security Hub re-evaluation to confirm CIS controls are still passing
- Send a deployment event to the monitoring stack (so post-deploy alerts can be correlated)
- Update the CHANGELOG with the deployment status

This is the operational handoff. After this stage, the application is in BAU and SSDLC-OPS-01 (continuous monitoring) takes over.

AXA mapping: SSDLC-OPS-01.

## What is NOT in this pipeline (and why)

A few things you might expect to see, that are deliberately not here:

**No IAST.** IAST agents (like Checkmarx IAST or Contrast) require runtime instrumentation. The training reference repo does not include a runtime test harness that would exercise the agent meaningfully. In a real pipeline, IAST would run during integration tests in a dedicated stage.

**No penetration test.** Pentests are scheduled activities (every 12 or 36 months per EIA), not per-build CI/CD activities. They are tracked separately in the pentest repository.

**No CSO security review.** The Security Review (SSDLC-DEP-02) is a formal gate involving a human approver outside the pipeline. The closest the pipeline gets is the manual approval gate in Stage 11.

**No SonarQube.** AXA-approved alternative for SAST. The pipeline uses SpotBugs+FindSecBugs because they are free and produce equivalent results for this reference. In production, swap in SonarQube or Checkmarx.

## Reading exercises

Once you understand the pipeline:

1. **Disable a gate and watch it break.** Set `failBuildOnCVSS=10` instead of `7`. Push a commit. Observe that Dep-Check now passes even if there is a CVSS 8 dependency. This is what removing a control looks like.

2. **Add a deliberate vulnerability.** Add a hardcoded secret to `application.properties`. Push to a feature branch. Watch the pre-commit hook block you (locally), and Stage 5 catch it (server-side) even if you bypass the local hook.

3. **Modify the Terraform to be insecure.** Remove the `aws_s3_bucket_public_access_block` resource. Push. Watch Stage 9 fail with `CKV_AWS_53`. Restore the resource. Watch it pass.

These exercises teach more than reading the workflow does.
