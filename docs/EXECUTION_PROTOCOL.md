# Autonomous issue execution protocol

Every implementation issue in this repository is intended to be executable autonomously once its dependencies and any explicitly named user prerequisite are satisfied.

## Authority

For an issue, authority is ordered as follows:

1. the issue body and acceptance criteria;
2. documents explicitly referenced by that issue;
3. `AGENT_CONTEXT.md`, `SCOPE.md`, `SECURITY_MODEL.md`, `EVIDENCE.md` and this protocol;
4. evidence/decisions from completed dependency issues;
5. current official Bytesized documentation where platform behaviour must be rechecked.

If authorities conflict, stop the conflicting portion, document it, and update the programme rather than improvising around a safety boundary.

## Standard workflow

### 1. Preflight

- Confirm dependency issues are completed or the issue explicitly allows parallel execution.
- Read every referenced document.
- Recheck current provider documentation if the issue depends on a provider capability/limit.
- Inspect existing evidence/decisions so work is not duplicated.
- Identify any user action that cannot be performed through available tools.

### 2. Branch

Create a narrowly named branch such as:

```text
issue-<number>/<short-slug>
```

Do not implement unrelated improvements in the same branch.

### 3. Implement

- Prefer small, reversible changes.
- Keep secrets outside Git.
- Use bounded tests appropriate to a shared host.
- Preserve cleanup/rollback commands.
- Update scripts/configuration in the repository so useful manual work does not remain undocumented shell history.

### 4. Verify locally/remotely

Run all applicable project checks, including at minimum:

```bash
python3 tools/validate_repo.py
```

and shell syntax checks for changed shell scripts.

For Appbox changes, verify the actual remote behaviour, not merely configuration text.

### 5. Capture evidence

Follow `EVIDENCE.md`. Add only public-safe, reasonably sized evidence. Update `DECISIONS.md` when an architectural choice changes.

### 6. Pull request

Open a PR against `main` with:

- `Closes #<issue>`;
- concise implementation summary;
- exact verification performed;
- evidence paths;
- security/cleanup notes;
- any remaining caveats.

### 7. Automated checks

Wait for repository checks to complete. If any check fails:

- inspect the failing job/log;
- fix the underlying problem;
- push the correction;
- wait for checks again.

Do not merge a knowingly failing PR merely because the failure seems unrelated.

### 8. Review state

Before merge:

- ensure no unresolved review thread represents a real defect;
- confirm the PR still matches issue scope;
- confirm no secret/private evidence entered the diff;
- confirm test artifacts/services were cleaned up or intentionally retained/documented.

### 9. Merge

The user has authorised autonomous merge after automated checks pass. Use a repository-supported merge method, preferring squash for single-issue implementation PRs unless preserving commits materially helps.

### 10. Reconcile

After merge:

- confirm the issue closed or close it with the correct reason;
- update dependency/roadmap metadata when necessary;
- create narrowly scoped follow-up issues for discovered work rather than silently expanding completed scope.

## User interaction rule

Ask for user action only when a capability is genuinely unavailable to the agent, especially:

- adding a public SSH key / repository secret;
- approving provider control-panel action;
- supplying a physical/local observation;
- authorising a scope expansion or purchase.

Never ask the user to paste a long-lived password/private key into chat or GitHub.

## Remote-access bootstrap

The first programme issue may require one-time user assistance because this chat does not inherently possess the user's Bytesized SSH credentials. The preferred bootstrap is a dedicated SSH key or a protected GitHub secret/environment route. Once established, later issues should minimise repeated manual terminal copy/paste.
