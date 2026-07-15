# Contributing to IdeaForge

Thank you for helping improve IdeaForge. Contributions are accepted under the
Apache License 2.0 and must follow the Developer Certificate of Origin (DCO).

## Developer Certificate of Origin

Every commit must include a `Signed-off-by` trailer certifying the Developer
Certificate of Origin 1.1 at <https://developercertificate.org/>. Add it with:

```sh
git commit --signoff
```

By signing off, you certify that you have the right to submit the contribution
under this repository's license. The sign-off is a legal certification; it is
not a GPG or SSH signature. Pull requests containing unsigned commits will not
be merged until their commits are corrected.

## Before opening a pull request

1. Keep changes focused and include tests for changed behavior.
2. Run `swift test` and the relevant script self-tests.
3. Run the public-source audit; do not include credentials, personal paths,
   device identifiers, private reports, or unprovenanced images.
4. Describe the user-visible behavior, verification performed, and remaining
   limitations in the pull request.

Please report security vulnerabilities privately as described in SECURITY.md,
not in a public issue.
