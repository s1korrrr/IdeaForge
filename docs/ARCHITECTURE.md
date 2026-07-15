# Architecture

## Components

```text
Apple Watch capture
        |
        | WatchConnectivity
        v
iPhone capture and review ----+
                              |
Mac studio and export --------+---- IdeaForgeCore ---- local workspace and encrypted objects
        |                     |
        | HTTPS               +---- backend clients and capability gates
        v
Community backend or operator service
        |
        +---- object storage, workspace state, jobs, usage, account URLs
        +---- optional transcription and workflow providers
```

`IdeaForgeCore` owns shared domain models, persistence rules, privacy modes, backend request contracts, capability gates, workflow validation, local object encryption, and packet export. Swift Package Manager tests this layer without launching an app.

The Mac app supplies the project studio, review and export tools, backend settings, web account-management handoff, and Sparkle updater. The iPhone app supplies mobile capture, review, backend upload and sync, Watch bridging, and StoreKit flows. The Watch app records and transfers captures through the paired iPhone.

## Local data boundary

Each Apple client stores its local workspace and recordings under its application container. Secrets and local object-store keys use Keychain. Packet export writes reviewable files after validating their paths. Local mode requires no backend credential.

The clients do not treat backend responses as trusted state on receipt. They require a validated session and matching workspace, check route capabilities, enforce privacy mode, validate response contracts, and apply sync conflict rules before persistence.

## Backend boundary

The repository contains `script/mock_backend.py`, a single-node community server. It uses a configured bearer token, one workspace scope, local object files, and SQLite. It can exercise the protocol and optional provider adapters. It cannot isolate unrelated users or meet production availability and operations requirements.

An operator may build a separate hosted service against [backend-contract.md](backend-contract.md). That service owns authentication, authorization, durable storage, provider calls, usage decisions, account URLs, deletion, monitoring, and compliance. No hosted production service is part of this source release.

## Commerce boundary

The iPhone distribution path can use StoreKit and submit Apple transaction evidence to a backend. The backend remains the authority for cloud entitlements after verification.

The direct-download Mac app cannot use App Store in-app purchase. It reads the plan summary from the backend and opens backend-provided HTTPS plan-management or deletion pages after capability and workspace checks.

## Release and update boundary

Community builds come from source and carry the distributor's identity. Official Mac builds add four release controls:

1. The protected GitHub workflow records the selected public commit and produces artifact provenance.
2. The maintainer signs the app and nested code with Developer ID and a secure timestamp.
3. Apple notarizes the app and DMG; the release process staples both tickets.
4. Sparkle verifies the update ZIP with an EdDSA signature tied to the public key in the app.

Each control answers a different trust question. [RELEASING.md](RELEASING.md) defines the evidence and failure gates.

## External gates

Repository tests cannot prove Apple account access, certificate private-key access, notary service acceptance, a live hosted backend, provider credentials, App Store Connect configuration, physical-device permissions, Watch transfer, or a clean-Mac update. Release reports must label these as external or physical gates until someone captures the corresponding evidence.

The repository also cannot establish asset authorship through a hash alone. [ASSET_PROVENANCE.md](../ASSET_PROVENANCE.md) records the maintainer's origin and license assertion for retained assets; the owner must confirm that assertion before the first public release.
