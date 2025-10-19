# Cencora Salesforce Unmanaged Package: Deployment, Redeploy, and CI/CD Guide

_Last updated: October 19, 2025_

## 1) Purpose & Scope
This document explains how Cencora will package, deploy, redeploy, and “upgrade” **unmanaged** Salesforce metadata across our orgs. It also outlines how we can automate deployments using Git and GitHub Actions (or a similar CI/CD service).

> **Key idea:** Unmanaged packages are editable in the target org. There is no strict upgrade path like managed packages; “upgrades” are essentially redeployments of changed metadata plus any cleanup.

---

## 2) Packaging & Source of Truth
We will keep **all metadata in Git** as the source of truth. There are two legitimate deployment paths for unmanaged content:

1. **Installable Unmanaged Package (optional):**
   - Create a **Packaging Sandbox** (or dedicated packaging org).
   - Use **Setup → Package Manager → New** to collect components and **Upload** a version.
   - Share the install URL for sandboxes/production. This is useful for first‑time installs or ad‑hoc distribution.

2. **Direct Metadata Deploy (preferred for repeatable releases):**
   - Store metadata in **Salesforce DX source format** under a single repo.
   - Deploy to each target org with SFDX/`sf` CLI via the Metadata API. This gives precise control, repeatability, and works well with CI/CD.

> We can use both approaches: an initial install via package URL, then subsequent updates via CI/CD deploys from Git.

---

## 3) Deployment Options
### A) Install via Unmanaged Package URL (UI‑driven)
**Use cases:** first‑time installs; quick distribution to a sandbox.
1. Build the package in the Packaging Sandbox, include all components.
2. Upload a version and copy the install links.
3. Target org admin installs via the URL and assigns any needed permission sets.
4. Run any manual post‑install configuration steps (documented in this guide / runbook).

**Pros:** Simple for first install; clean UX.  
**Cons:** Limited control over selective components, no deletions, no automation hooks.

### B) Direct Deploy from Git (CLI‑driven) — **Recommended**
**Prereqs:** Org auth is set up (JWT or web login), `sf` CLI installed in CI, package.xml maintained.

**Typical commands**
```bash
# Convert SFDX source to Metadata API format (only if using mdapi deploy)
sf project convert source --root-dir force-app --output-dir mdapi

# Validate-only deployment (no changes committed yet)
sf project deploy start \
  --manifest manifest/package.xml \
  --dry-run \
  --test-level RunLocalTests

# Full deploy
sf project deploy start \
  --manifest manifest/package.xml \
  --test-level RunLocalTests \
  --ignore-conflicts

# Optional: deletions (cleanup)
sf project deploy start \
  --manifest manifest/destructiveChanges.xml \
  --predestructivechanges manifest/destructiveChanges.xml \
  --postdestructivechanges manifest/package.xml
```

**Best practices**
- Use **validate-only** in production gates.
- Keep a **per‑org manifest** when necessary.
- Use **permission sets** (not Profiles) to grant access.
- Externalize environment differences via **Custom Metadata Types**, **Custom Settings**, and **Named Credentials**.

---

## 4) Making Changes & Redeploying to a Specific Org
1. Create a feature branch; implement and test locally/in a sandbox.
2. Open a PR to `develop`; require code review + tests.
3. Merge to `main` to cut a release tag (e.g., `v2025.10.19`).
4. CI deploys to the target org (e.g., only `CENC‑SBX1`) using that org’s manifest and secrets.
5. If components must be **removed**, include a `destructiveChanges.xml` in the release.
6. Post‑deploy: run scripts to seed data, assign permission sets, run `Apex` anonymous for data fixers if needed.

> Because metadata remains editable in the destination org, we should **treat Git as canonical** and actively avoid hand‑edits in target orgs (or back‑sync them via `sf project retrieve start`).

---

## 5) “Upgrading” an Unmanaged Package
Unmanaged packages **do not** support upgrades like managed/unlocked packages. Our upgrade model is:
- **Overwrite strategy:** Re‑deploy the changed metadata from Git. Changed files will overwrite.
- **Removal strategy:** Use `destructiveChanges.xml` for deletions.
- **Data/config migrations:** Trigger via post‑deploy scripts or `Apex`/`SOQL` fixers.
- **Versioning:** Tag every deploy; keep CHANGELOG of what changed, any manual steps, and rollback notes.
- **Rollback:** Keep the last known‑good tag and manifest to redeploy if needed.

> If strict versioning and true upgrades become important, consider **Unlocked Packages** in the future. For now, unmanaged + CI/CD provides flexibility and speed for internal orgs.

---

## 6) CI/CD with GitHub Actions (Optional but Recommended)
We can automatically push changes to selected orgs after merges. Below is a reference workflow using **JWT** authentication:

### Secrets per Org
Each org (e.g., Developer A, Developer B, QA, Production) has its own set of GitHub repository secrets for authentication. Example naming pattern:

- `SF_CONSUMER_KEY_DEV_A`  
- `SF_JWT_KEY_DEV_A`  (Base64‑encoded private key)  
- `SF_USERNAME_DEV_A`  
- `SF_LOGIN_URL_DEV_A`

- `SF_CONSUMER_KEY_DEV_B`  
- `SF_JWT_KEY_DEV_B`  
- `SF_USERNAME_DEV_B`  
- `SF_LOGIN_URL_DEV_B`

The workflow dynamically selects which secret group to use based on the `org` input. This allows multiple environments to coexist safely with their own credentials and Connected Apps. For simultaneous multi‑org deployments, a **matrix strategy** can be used in the workflow.

GitHub also supports **Environments** (e.g., DEV, QA, PROD) to restrict deployments and approvals while keeping each environment’s secrets isolated.

### Sample reusable Action: `.github/workflows/deploy.yml`
```yaml
name: Deploy to Salesforce
on:
  workflow_dispatch:
    inputs:
      org:
        description: 'Org alias (e.g., DEV_A, DEV_B, CENC-SBX1, CENC-PROD)'
        required: true
      ref:
        description: 'Git ref (commit/branch/tag)'
        required: true
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.inputs.ref || github.ref }}

      - name: Setup SF CLI
        uses: salesforcecli/action-setup@v2

      - name: Decode JWT key
        id: jwt
        run: |
          echo "${{ secrets[format('SF_JWT_KEY_{0}', inputs.org)] }}" | base64 -d > jwt.key

      - name: Auth to Org
        run: |
          sf org login jwt \
            --username "${{ secrets[format('SF_USERNAME_{0}', inputs.org)] }}" \
            --jwt-key-file jwt.key \
            --client-id "${{ secrets[format('SF_CONSUMER_KEY_{0}', inputs.org)] }}" \
            --instance-url "${{ secrets[format('SF_LOGIN_URL_{0}', inputs.org)] }}" \
            --alias target

      - name: Pre-Deploy Checks
        run: |
          sf apex run test --target-org target --code-coverage --result-format human --test-level RunLocalTests --wait 20 || true

      - name: Validate Deploy
        run: |
          sf project deploy start \
            --manifest manifest/package.${{ inputs.org }}.xml \
            --dry-run \
            --test-level RunLocalTests \
            --target-org target --wait 60

      - name: Deploy
        if: success()
        run: |
          sf project deploy start \
            --manifest manifest/package.${{ inputs.org }}.xml \
            --test-level RunLocalTests \
            --target-org target --wait 60

      - name: Post-Deploy
        run: |
          bash scripts/postdeploy.sh target
```

### Enhancements
- **Matrix deploys** to multiple sandboxes post‑merge; gated promotion to production.
- **Static analysis** (PMD/Code Analyzer) and lint in PRs.
- **Scratch org spins** for preview builds.
- **Notifications** (Slack/Teams) on success/failure with links to the release tag.

---

## 7) Org‑Specific Configuration Strategy
- Use **Custom Metadata Types (CMDT)** and **Hierarchy Custom Settings** for environment variables (endpoints, feature flags, record type IDs).
- Keep CMDT records in source where possible; where per‑org values differ, store them under `config/environments/` and load via post‑deploy script (Apex/data API).
- Keep **Named Credentials** and **External Credentials** for external integrations; set secrets in the org, not in Git.
- Grant access via **Permission Sets** and **Permission Set Groups**; avoid profile edits.

---

## 8) Governance, Testing, and Rollback
- **Change control:** PR reviews by at least one senior dev; require passing tests.
- **Test levels:** `RunLocalTests` for sandboxes and production. Consider `--tests` for critical suites.
- **Release notes:** Maintain `docs/CHANGELOG.md` per tag; include manual steps.
- **Rollback:** Re‑deploy the previous tag’s manifest; include data backout scripts if necessary.

---

## 9) Appendix: Useful Commands
```bash
# Retrieve changes from a sandbox to sync back to Git
sf project retrieve start --manifest manifest/package.CENC-SBX1.xml --target-org CENC-SBX1

# Convert source (if using mdapi-style flows)
sf project convert source --root-dir force-app --output-dir mdapi

# Run tests with coverage report
sf apex run test --test-level RunLocalTests --result-format human --wait 20 --target-org target

# Assign permission set(s)
sf org assign permset --name My_App_User --target-org target

# Execute anonymous Apex (e.g., data migration snippet)
sf apex run --file scripts/dataFixer.apex --target-org target
```

---

### Summary
- Treat **Git as the source of truth**.
- Prefer **CLI‑driven deploys** for repeatability; use unmanaged package install links for initial distribution only.
- For “upgrades,” **redeploy** changed metadata and use **destructive changes** for removals.
- Use **GitHub Actions** (or equivalent) to automate validation and deployments to the right Cencora orgs in a controlled, auditable way.

