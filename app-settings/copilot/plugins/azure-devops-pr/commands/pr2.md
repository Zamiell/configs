---
name: pr2
description: Create and autonomously complete an Azure DevOps pull request.
---

Manage the Azure DevOps pull request for the current Git branch from creation
until all required policies pass.

1. Inspect the working tree, repository instructions, current branch, upstream,
   remotes, and default target branch. Identify the Azure DevOps repository from
   the current branch's upstream or push remote. Stop with a clear explanation
   if the repository is not hosted in Azure DevOps, the current branch is the
   target branch, credentials are unavailable, or committing would include
   secrets.
2. Validate all pending changes according to the repository instructions. Fix
   validation failures caused by the pending changes.
3. Commit all intended tracked and untracked changes using an appropriate
   commit message, including any repository-required trailers, and push the
   current branch to its Azure DevOps remote. Do not amend existing commits,
   force-push, or include unrelated generated files, credentials, or secrets.
4. Find the active pull request for the current source branch and repository.
   If none exists, create one targeting the repository's default branch with an
   accurate title and description derived from the complete branch diff. If one
   exists, update its title or description when they no longer describe the
   branch.
5. Wait for all required Azure DevOps branch policies and checks to finish.
   Inspect failed `check-pull-request` jobs and their logs. Fix actionable lint,
   formatting, test, or validation failures caused by this branch, run the
   smallest relevant local validation, commit the fix, push it, and wait for
   the replacement check.
6. Inspect all active pull request comment threads whenever checks or reviews
   change:
   - If feedback is correct, implement the complete fix, validate it, commit it,
     push it, reply with a concise explanation, and resolve the thread when
     appropriate.
   - If feedback is incorrect or already satisfied, verify that conclusion,
     reply on the thread with the concrete evidence or rationale, and resolve
     the thread without changing the code.
7. Continue polling and repeat the failure and feedback loops until every
   required policy passes and no active actionable thread remains. Do not stop
   merely because a new commit was pushed or checks are still running. If a
   policy requires human approval or an external service is unavailable,
   continue monitoring when practical; otherwise report the exact blocker and
   leave the pull request in the safest valid state.

Use the Azure DevOps REST API when no purpose-built tool is available. Derive
the organization, project, repository, source branch, and API base URL from Git
rather than hard-coding them. Prefer existing authenticated tooling. If a
personal access token is needed for an `azuredevops.logixhealth.com` remote, use
`AZDO_PERSONAL_ACCESS_TOKEN_SERVER`; for a `dev.azure.com/logixhealth` remote,
use `AZDO_PERSONAL_ACCESS_TOKEN_SERVICES`. Never print credentials or include
them in command output, files, commits, pull request text, or comments.
