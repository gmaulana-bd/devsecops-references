# Changelog

All notable changes to this project will be documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

CHANGELOG maintenance is required for DORA audit compliance (Article 8).
Every release must document features added, CVEs patched, and breaking changes.

## [1.0.0] - 2026-05-29
### Added
- Initial reference application: trivial Spring Boot REST API with two endpoints
- Complete CI/CD pipeline in `.github/workflows/devsecops.yml` covering 12 stages
- Pre-commit hook for client-side secret detection (Gitleaks)
- SpotBugs with FindSecBugs for SAST
- OWASP Dependency-Check for SCA, configured to fail on CVSS 7.0+
- CycloneDX SBOM generation
- Distroless Dockerfile (gcr.io/distroless/java17-debian12:nonroot)
- Trivy container scanning in CI
- Checkov IaC scanning for Terraform, Kubernetes, and Dockerfile
- OWASP ZAP baseline DAST scan for staging
- GitHub Environments deployment gate (production)
- Kubernetes manifest with full security context hardening (readOnlyRootFilesystem, no privilege escalation, dropped capabilities)
- Terraform module demonstrating CIS AWS Foundations Benchmark v5.0.0 compliance:
  - S3 with Block Public Access, SSL-only policy, encryption, versioning, access logging
  - RDS with no public access, encryption at rest, Multi-AZ
  - KMS key with automatic rotation
  - Least-privilege IAM role (no AdministratorAccess)
- CODEOWNERS enforcing Security Champion review on security-sensitive paths

### Security
- All inputs to the REST API are validated server-side using an allow-list pattern
- Application configuration uses ${ENV_VAR} placeholders, never hardcoded secrets
- Maven Enforcer banning -SNAPSHOT and version ranges in production builds
- GitHub Actions pinned to commit SHA, not tags
- Workflow permissions explicitly minimized (contents: read by default)
