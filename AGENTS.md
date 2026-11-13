# Journal contributor instructions

Read `docs/PRODUCT.md` before changing product behavior. Current user instructions take precedence over historical specifications. This is the new native iPhone project; the old Flutter repository is reference material only.

- Swift 6, iOS 18+, SwiftUI and system Apple frameworks. No website or cross-platform runtime.
- Keep core logic in `Sources/JournalCore`, UI in `App`. No external app dependencies without a concrete need.
- All academic dates and time arithmetic use `Day` and Europe/Minsk. Never substitute the host timezone.
- Preserve user data, cancellation, offline archive and corrupted original files. Persist successfully before publishing mutations.
- All subgroups remain visible. No widgets, Live Activities, notifications, analytics, accounts or cloud sync in this scope.
- UI copy and user documentation are Russian and use plain language. Do not expose technical details in normal flows.
- Use semantic colors, SF Symbols, Dynamic Type and system navigation. Guard iOS 26 APIs and retain iOS 18 behavior.
- After changing App/AppTests/UITests file membership or version.json, run `python3 scripts/generate_project.py` and commit generated project files.
- Use focused behavioral tests. Run `swift test --parallel` and the iOS workflow for affected behavior. Never call an unexecuted check passed.
- GitHub work: short branch, PR, checks, squash. Do not force push main or replace published tags/assets. Minimize Actions; no scheduled polling workflow.
- Release metadata lives in version.json. A stable release requires the owner's device check; prereleases must state what remains unverified.
- Do not commit tokens, signing certificates/profiles, device logs with personal data or real backups. Do not modify generated Codex memory.
