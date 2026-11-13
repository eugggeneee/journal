# Journal contributor instructions

Read `docs/PRODUCT.md` before changing product behavior. Current user instructions take precedence over historical specifications. This is the new native iPhone project; the old Flutter repository is reference material only.

- Swift 6, iOS 18+, SwiftUI and system Apple frameworks. No website or cross-platform runtime.
- Keep core logic in `Sources/JournalCore`, UI in `App`. No external app dependencies without a concrete need.
- All academic dates and time arithmetic use `Day` and Europe/Minsk. Never substitute the host timezone.
- Preserve user data, cancellation, offline archive and corrupted original files. Persist successfully before publishing mutations.
- All subgroups remain visible. No widgets, Live Activities, notifications, analytics, accounts or cloud sync in this scope.
- UI copy and user documentation are Russian and use plain language. Do not expose technical details in normal flows.
- Use semantic colors, SF Symbols and system navigation. Per the owner's explicit beta.2 decision, use the standard Large text category (17 pt body) independently of the device's text-size setting; use regular/bold for app-authored type. Adapt layout to available width and orientation. Record this exception to HIG Dynamic Type guidance in docs/DESIGN_REVIEW.md. Guard iOS 26 APIs and retain iOS 18 behavior.
- After changing App/AppTests/UITests file membership or version.json, run `python3 scripts/generate_project.py` and commit generated project files.
- Use focused behavioral tests. Run `swift test --parallel` and the iOS workflow for affected behavior. Never call an unexecuted check passed.
- GitHub work: short branch, PR, checks, squash. Do not force push main or replace published tags/assets. Minimize Actions; no scheduled polling workflow.
- Describe every commit and other Git/GitHub write action in Russian using concrete past-tense sections: «Сделано», «Добавлено», «Переделано», «Убрано», «Исправлено», «Проверено», as applicable. Explain what changed, why and the actual validation; omit empty sections. Use a specific past-tense subject and a detailed body for commits, PRs, annotated tags and release notes. Report branch, merge, push and repository-setting actions with the same wording. Never invent completed work or rewrite published history merely to change its wording. See CONTRIBUTING.md.
- Release metadata lives in version.json. A stable release requires the owner's device check; prereleases must state what remains unverified.
- Do not commit tokens, signing certificates/profiles, device logs with personal data or real backups. Do not modify generated Codex memory.
