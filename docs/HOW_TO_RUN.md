# How to Run

Three ways to use this repo, in order of effort.

## Option 1: Read it (5 minutes)

You do not need to install anything to learn from this repo.

1. Read [README.md](../README.md) for the overview.
2. Read [docs/LIFECYCLE_DIAGRAM.md](LIFECYCLE_DIAGRAM.md) for the visual picture.
3. Read [docs/PIPELINE.md](PIPELINE.md) for the line-by-line walkthrough.
4. Open [.github/workflows/devsecops.yml](../.github/workflows/devsecops.yml) and read it alongside `PIPELINE.md`.

If you stop here, you have understood how the full DevSecOps lifecycle works in practice. That is enough for most people.

## Option 2: Run the pre-commit hook locally (15 minutes)

This shows you Stage 1 (secret detection) working on your own machine, without any GitHub setup.

### Prerequisites
- Git installed
- Python 3 installed (for `pip install pre-commit`)

### Steps
```bash
# Clone the repository
git clone https://github.com/YOUR-ORG/devsecops-reference.git
cd devsecops-reference

# Install pre-commit
pip install pre-commit

# Install Gitleaks (one of the following)
brew install gitleaks                    # macOS
sudo apt-get install gitleaks            # Ubuntu or Debian
choco install gitleaks                   # Windows with Chocolatey

# Activate the pre-commit hooks
pre-commit install
```

### Try to commit a secret

Create a file containing a fake AWS credential:

```bash
echo 'AWS_KEY=AKIAIOSFODNN7EXAMPLEXX' >> test_secret.txt
git add test_secret.txt
git commit -m "Try to commit a secret"
```

Expected outcome: the commit is rejected with a Gitleaks error showing the file, the line, and the type of secret detected.

Clean up:
```bash
rm test_secret.txt
git reset HEAD
```

## Option 3: Fork and watch the full pipeline (45 minutes)

This shows you all 12 stages running on GitHub Actions, end to end.

### Prerequisites
- A GitHub account
- Git installed

### Steps

**1. Fork the repository.** Click "Fork" on the GitHub UI.

**2. Clone your fork.**
```bash
git clone https://github.com/YOUR-USERNAME/devsecops-reference.git
cd devsecops-reference
```

**3. Enable GitHub Actions.** Go to your fork's "Actions" tab. If prompted, click "I understand my workflows, go ahead and enable them."

**4. Push a commit to trigger the pipeline.**
```bash
git commit --allow-empty -m "Trigger DevSecOps pipeline"
git push
```

**5. Watch the pipeline run.** Go to the Actions tab. Click on the running workflow. You will see all 12 stages, some running in parallel (SAST, SCA, secret scan all start at the same time).

### Expected timing
- Build, SAST, SCA, secret scan: each completes in 2 to 5 minutes
- Container build, Trivy: 2 to 3 minutes
- Checkov: 30 seconds
- DAST: only runs on push to `develop`
- Deploy: blocked at manual approval gate (configure in GitHub Settings to approve yourself)
- Post-deploy: a few seconds (placeholders, no real cloud calls)

Total pipeline wall time: 8 to 12 minutes.

### What you should see

**Pass:** the first push runs cleanly because the repo is intentionally clean. All checks green.

**Fail (deliberately):** edit `pom.xml` to add a vulnerable dependency:
```xml
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-core</artifactId>
    <version>2.14.0</version>  <!-- vulnerable to Log4Shell -->
</dependency>
```
Push and watch Stage 4 (SCA) fail with `CVE-2021-44228`. This is what the pipeline is designed to catch.

### Configure the deployment approval (optional)

To see the manual approval gate work:
1. Go to your fork's Settings → Environments
2. Click "New environment", name it `production`
3. Under "Deployment protection rules", enable "Required reviewers" and add yourself
4. Save

Now push to `main` (or merge a PR to `main`). The Deploy stage will pause and notify you. Approve it in the GitHub UI to let it proceed.

## Troubleshooting

**The NVD database download in Stage 4 is slow on the first run.** Normal. It downloads around 200MB of CVE data the first time, then caches it. Subsequent runs are much faster.

**Trivy fails with "image not found".** The pipeline rebuilds the image in Stage 8 because Docker images do not transfer cleanly via workflow artifacts. This is intentional but adds 1 to 2 minutes.

**Checkov reports findings on real Terraform but passes on the included `main.tf`.** The `main.tf` in this repo is intentionally CIS-compliant. Modify it to remove a security control (e.g. delete the `aws_s3_bucket_public_access_block` resource) and Checkov will fail. This is how you verify the scanner is actually doing something.

**The DAST stage is skipped.** DAST only runs on push to the `develop` branch, not on PRs or on `main`. This is intentional. DAST requires a deployed staging environment and is not needed on every PR.

**The Deploy stage is blocked.** It is blocked until a required reviewer approves it via the GitHub UI. This is the 4-eyes principle (SSDLC-DEP-03) working as intended. Configure the production environment as described above to be able to approve it.
