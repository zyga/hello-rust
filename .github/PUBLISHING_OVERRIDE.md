# Publishing Override Guide

## Overview

This guide explains how to use the manual override feature that allows publishing to the Snap Store even when integration tests (spread) fail or are skipped.

This feature addresses scenarios where:
- Integration tests are temporarily flaky but don't reflect real snap issues
- You need an emergency hotfix release
- You want to test the publishing pipeline without running the full test suite

## How to Trigger the Override

### Step 1: Navigate to Actions

1. Go to your GitHub repository
2. Click the **Actions** tab
3. Select the **Build** workflow on the left sidebar

### Step 2: Run the Workflow with Override

1. Click the **"Run workflow ▼"** dropdown button
2. A panel appears with the following options:
   ```
   Branch: [main ▼]
   
   ☐ Skip integration tests
   
   [Run workflow] button
   ```

3. Select your branch (usually `main`)
4. **Check the box** for "Skip integration tests" to enable the override
5. Click **"Run workflow"**

### Step 3: Workflow Execution

The workflow will:

1. **Run unit tests** (`cargo test`) — **still required** and cannot be skipped
   - If unit tests fail, the workflow fails immediately
   - Integration tests are only skipped if this passes

2. **Build snaps** for both amd64 and arm64 architectures
   - This step proceeds regardless of test outcome

3. **Skip spread tests** (integration tests)
   - You'll see "skipped" status in the Actions UI (yellow indicator)
   - This step is completely skipped, not failed

4. **Wait for approval** before publishing
   - The "Snapcraft Upload" job enters a **blocked/pending** state
   - Appears with an orange indicator in the Actions UI
   - Notification sent to approvers

### Step 4: Approval Process

Once the workflow reaches the upload step:

1. **In the Actions UI:**
   - Go to the specific workflow run
   - Find the blocked **"Snapcraft Upload"** job
   - You'll see buttons: **[Approve] [Reject] [View reviewers →]**

2. **Click Approve** (or Reject)
   - Shows in a modal: "Add review comment" (optional)
   - Confirms your approval

3. **After approval:**
   - Upload job proceeds
   - Snaps publish to the channel specified in `vars.SNAPCRAFT_CHANNEL` (or edge/candidate)
   - Workflow completes successfully

## GitHub UI Screenshots (Conceptual)

### "Run workflow" Dialog

```
┌────────────────────────────────────────┐
│ Run workflow on branch                 │
├────────────────────────────────────────┤
│ Branch: [ main                    ▼ ]  │
│                                         │
│ Inputs:                                 │
│ ☐ Skip integration tests               │
│   (unchecked by default — safe default) │
│                                         │
│ [Run workflow]                          │
└────────────────────────────────────────┘
```

### Workflow Execution (tests skipped)

```
Workflow Run: Build

Status: In progress

Jobs:
  ✓ Build and test (completed)
  ✓ Snapcraft Pack AMD64 (completed)
  ✓ Snapcraft Pack ARM64 (completed)
  ⊘ Spread AMD64 (skipped)          ← Yellow indicator
  ⊘ Spread ARM64 (skipped)          ← Yellow indicator
  ⏸ Snapcraft Upload (blocked)      ← Orange indicator
     ↳ Awaiting approval
```

### Approval Gate Modal

```
┌─────────────────────────────────────────────────┐
│ Review and approve "Snapcraft Upload" job       │
├─────────────────────────────────────────────────┤
│ This job requires approval from:                │
│ - Repository maintainers                        │
│ - Users with deployment permissions             │
│                                                  │
│ Triggered by: @username                         │
│ Branch: main                                    │
│ Spread tests: SKIPPED                           │
│                                                  │
│ Comment (optional):                             │
│ ┌──────────────────────────────────────────┐   │
│ │ (leave blank or add reasoning)           │   │
│ └──────────────────────────────────────────┘   │
│                                                  │
│ [Approve] [Reject]                              │
└─────────────────────────────────────────────────┘
```

## Setup: Approval Gate (Optional but Recommended)

### Create a New GitHub Environment (Safety Layer)

To require explicit approval before any override-based publishing:

1. Go to **Settings → Environments** in your repository
2. Click **"New environment"**
3. Name: `snapcraft-release-override`
4. Click **"Configure environment"**

### Add Deployment Branches

1. Under "Deployment branches":
   - Select: "Selected branches"
   - Add branches that need approval (e.g., `main`, `develop`)

### Add Approval Rules

1. Check: **"Required reviewers"**
2. Add users/teams who can approve override uploads
   - Typically: repository maintainers
   - Add at least 2 people for sensitive repos

### Add Environment Secret

1. Under "Environment secrets":
2. Click **"Add secret"**
3. Name: `SNAPCRAFT_STORE_CREDENTIALS`
4. Value: (same credentials export as `latest/edge` or `latest/candidate`)
   ```bash
   snapcraft export-login \
     --snaps=hello-rust-zygoon \
     --channels=latest/edge \
     --acls=package_upload,package_release \
     token.txt
   ```

## Audit Trail

GitHub automatically logs all override invocations:

- **Who**: GitHub username that triggered it
- **When**: Timestamp of the workflow dispatch
- **What**: Workflow parameters (skip-spread-tests: true)
- **Result**: Success/failure and what was published
- **Approval**: Who approved the upload and when

View this in:
- GitHub Actions → Workflow run details → "Logs" tab
- Settings → Audit log (for organization-level tracking)
- API: `GET /repos/{owner}/{repo}/actions/runs`

## Risks and Safeguards

### Risks of Skipping Integration Tests

| Risk | Mitigation |
|------|-----------|
| Publish snap with runtime bugs | Unit tests still required; use override sparingly |
| Miss platform-specific issues | Integration tests run in real VMs; skipping loses this |
| Create inconsistent releases | Audit trail shows which releases used override |
| Accidental bypass | Override requires explicit checkbox and approval |

### How to Mitigate

1. **Only use for proven flakiness**
   - First, run the workflow normally to confirm spread failures are flaky
   - Document which tests are problematic

2. **Require approval**
   - Set up the `snapcraft-release-override` environment (see above)
   - Require at least 2 approvers for sensitive projects

3. **Publish to edge first**
   - Publish to `latest/edge` via override, not `latest/candidate`
   - Let real users test before promoting to stable

4. **Monitor snap stability**
   - Watch for reports of the override-published snap in the Snap Store
   - If issues arise, document them and fix the integration tests

## Examples

### Emergency Hotfix for Production Issue

```
1. Fix the code in main branch
2. Create a tag: git tag v1.2.3 && git push --tags
3. GitHub automatically triggers build workflow
4. Integration tests fail (flaky)
5. Use override:
   - Actions → Build → Run workflow
   - Check "Skip integration tests"
   - Run workflow
6. Approve the upload when prompted
7. Snap publishes to latest/candidate (tag → candidate channel)
8. Use separate promote workflow to move to latest/stable
```

### Testing Publishing Pipeline

```
1. Push branch to feature/test-publish
2. Actions → Build → Run workflow
3. Select branch: feature/test-publish
4. Check "Skip integration tests"
5. Run workflow
6. Approve upload
7. Snap publishes to latest/edge (branch → edge channel)
8. Verify publish succeeded without full test run
```

## Troubleshooting

### "Run workflow" button doesn't show inputs

- The workflow must have `workflow_dispatch` in the `on:` trigger
- Check [build.yml](.github/workflows/build.yml) includes the input definition
- Push changes to branch and try again

### Workflow runs but spread tests still run

- Check that `skip-spread-tests` input is properly passed to `tasteful-crafts.yml`
- Verify the spread job has `if: ${{ !inputs.skip-spread-tests }}`

### Upload job is skipped instead of waiting for approval

- Environment approval rule may not be configured
- Check Settings → Environments → Check if `snapcraft-release-override` exists
- Ensure the environment has required reviewers set

### "Add Required Reviewers" option is greyed out

- This feature requires a paid GitHub plan (Pro or Team)
- Alternative: Ask human reviewers manually via PR/issue before clicking Approve

## See Also

- [build.yml](.github/workflows/build.yml) — Workflow definition with override input
- [tasteful-crafts.yml](.github/workflows/tasteful-crafts.yml) — Where spread tests are skipped
- [GitHub Docs: Workflow Dispatch](https://docs.github.com/en/actions/using-workflows/manually-running-a-workflow)
- [GitHub Docs: Environments and Secrets](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub Docs: Required Reviewers](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments#required-reviewers)
