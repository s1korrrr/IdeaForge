# Repository settings for a public release

This file records repository-host settings that cannot be enforced by source
files alone. Apply them only after owner approval, then capture screenshots or
API output in the release dossier.

## Current verified state (2026-07-20)

- Repository: `s1korrrr/IdeaForge`, public, default branch `main`.
- Private vulnerability reporting, secret scanning, push protection,
  Dependabot alerts, and automated security fixes are enabled.
- Actions default token permissions are read-only. Current workflow actions are
  pinned to full commit IDs.
- The `release` environment requires owner review and is limited to `v*` tags.
- `main` has no classic protection or ruleset; no release-tag ruleset exists.
- Sparkle is not present in GitHub's dependency graph from the current public
  revision, so the empty alert result does not establish Sparkle coverage.
- No tags, GitHub releases, or release workflow runs exist.

## Required `main` ruleset

Target the default branch and require:

1. Pull requests with at least one approval from an effective CODEOWNER.
2. The exact `CI / verify` required status check from the protected base SHA.
3. Conversation resolution and dismissal of stale approvals after new commits.
4. Linear history, no force pushes, and no deletion.
5. Explicit, narrow emergency bypass actors with bypass activity audited.

Do not claim the DCO policy is enforced until a required DCO status check is
also configured.

## Required `v*` tag ruleset

- Restrict tag creation, update, and deletion to release maintainers.
- Do not permit force updates.
- Keep the protected `release` environment restricted to matching tags and an
  owner approval.

## Dependency and code security

- Add an official, immutable dependency-submission path for the Xcode project's
  generated `Package.resolved`, then verify Sparkle revision
  `b6496a74a087257ef5e6da1c5b29a447a60f5bd7` appears in the dependency graph.
- Enable a supported Swift code-scanning configuration and confirm that an
  analysis for the exact release commit completes. Do not treat “no analysis”
  as “no findings.”
- Keep private vulnerability reporting, secret scanning, push protection,
  Dependabot alerts, and automated security fixes enabled.

## Repository identity decisions

The current public URL is under the founder's personal account. Before changing
URLs or release feeds, the owner must choose whether to retain
`s1korrrr/IdeaForge` or transfer the repository to the `rsitech-ai` organization.
A transfer is an external, potentially disruptive operation and requires a
separate migration plan for badges, appcast URLs, SBOM references, release
links, CODEOWNERS, and profile pins.

Leave the homepage blank until a real, maintained project URL is approved.
Labels, social preview, profile README, and profile pins are useful polish, but
they are external writes and are not prerequisites for source correctness.
