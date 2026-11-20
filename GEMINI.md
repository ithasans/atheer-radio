# Project Boundaries and Constraints

## 1. Cloud & CI/CD Restrictions (Strictly Enforced)
- **NO Automatic Triggers**: Workflows in `.github/workflows/` must NEVER include `on: push`, `on: pull_request`, or `schedule`.
- **NO Windows or Android Cloud Builds**: Windows and Android builds must ALWAYS be performed 100% locally on the developer machine. Never create, add, or trigger GitHub Actions workflows for Windows or Android.
- **iOS IPA Builds Only**: The only permitted cloud workflow is for iOS (`.github/workflows/build_ios.yml`), and it must ONLY be triggered manually via `workflow_dispatch` upon explicit user request.
- **Account Quota Protection**: Never perform any action that consumes GitHub Actions minutes, external API credits, or cloud compute without prior, explicit, written authorization from the user.
