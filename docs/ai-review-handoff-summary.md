# Network Diagnostics App — External AI Review Handoff Summary

> Source: internal audit doc `docs/project-review-2026-09-27.md`, updated by `docs/PRD.md` §8 and `docs/implementation-plan.md` M6.
> Date: 2026-09-27
> Purpose: concise, self-contained summary for a second-opinion review by an external AI.

## 1. Project Context

- **Product**: NetDoctor (formerly NetworkConsole Lite) — a read-only macOS network diagnostic app for the Mac App Store. Swift, SwiftPM (`swift build` / `swift test`), xcodegen.
- **Store status**: Already published on Apple App Store Connect (v1.1, distributable). Bundle ID `com.networkconsole.lite`, SKU `networkconsole-lite-0001`, Apple ID 6801707344. Store primary language: English (US). Category: Utilities.
  - Implication: version-upgrade review risk must be managed; Store metadata that is already live should be changed as little as possible.
- **Hard constraints (AGENTS.md)**:
  - Read-only diagnostics; MUST NOT call `Process`/`NSTask`/shell/subprocesses; MUST NOT install Privileged Helper/LaunchDaemon; no admin rights.
  - No hardcoded enterprise domains/IPs/certs/ports; no AOne/EasyConnect/Clash/SSH/auth code.
  - Tests must have zero real-network dependency (mock injection). No telemetry; no upload by default.
- **Current verification**: `swift build` ✅, `swift test` ✅ (16 tests, 0 failed, ~0.007s, all mock), xcodegen drift ✅, hard-rule compliance scan ✅.

## 2. High Priority Findings

### H1 — Localization coverage missing for 6 languages (v1.2 target)
- Evidence: `Sources/NetworkConsoleApp/Localization.swift` — `zh`=248 keys (baseline), `en`=248; `ja`=164 (84 missing), `ko/de/fr/es/pt`=131 each (117 missing). Missing keys are post-"UI Revamp" additions: `verdict.*`, `settings.engine.*`, `settings.auto.*`, `settings.privacy.*`, `card.*`, `timeline.filter.*`, `dnsRoute.dns.*`, `interfaces.telemetry.*`.
- Impact: non-Chinese/English users fall back to English; contradicts commit "fix(l10n): eliminate mixed English/Chinese".
- Decision (confirmed): 8-language 100% coverage remains the product target; missing keys are app-internal localization only and are independent from Store metadata (Store lists only English, that's fine). Adding translations is purely additive and must not affect version-upgrade review.
- Fallback chain fix required: current chain is `dict → en → zh`; must be fixed to always fall back to **en**, never leak Chinese to non-Chinese users. v1.2 ship gate (transition state): zh/en 100% identical + other languages fall back to English with **no Chinese leakage**; target state: zero gaps.

### H2 — SSID feature may silently fail in sandbox (publish-blocking, needs decision)
- Evidence: `Config/NetworkConsoleLite.entitlements` has only app-sandbox / files.user-selected.read-write / network.client — **missing** `com.apple.developer.networking.wifi-info`. `SystemInterfaceCollector` calls `CWWiFiClient.shared().interface()?.ssid()`.
- Impact: in sandbox, `ssid()` returns nil without that entitlement → "Wi-Fi SSID" display and SSID redaction in support package silently no-op in the App Store build.
- Options: (a) request WiFi-info entitlement from Apple and disclose in review, or (b) remove SSID capability from UI/export. Must be decided before next submission.

### H3 — Fragile i18n architecture: Chinese hardcoded in core + string-match lookup (v1.2)
- Evidence: `HealthGrader.swift` verdict/advice/summary hardcoded Chinese; `DiagnosticEngine.swift` TimelineEvent messages hardcoded Chinese; `AppModel.swift` maps them back to L10n keys by `switch`-matching the Chinese strings (lines ~399-428, ~475-515).
- Impact: any wording tweak in core breaks mapping → fallback leaks raw Chinese. Tests `XCTAssertEqual(verdict, "全链路畅通 · 状态极佳")` pin Chinese in tests.
- Fix: core returns typed enum codes (verdict code, advice code); App layer maps code → L10n; TimelineEvent `message` for logging only, UI rebuilt from `arguments`.

### H4 — Testing gaps (v1.2)
- Only `NetworkCoreTests` exists (16 cases). No App-layer tests: `AppModel`, `L10n`, `AppLanguage`, `localizedVerdict/localizedAdvice` untested. `SupportPackageExporterTests` only covers SSID redaction, not IP/DNS/gateway/timeline export.
- Fix: new `NetworkConsoleAppTests` target — L10n key completeness (zh baseline, fail if any language missing keys), `AppLanguage.resolveEffective`, localization mapping (with mocked engine); extend redaction boundary tests and document the redaction policy.

## 3. Medium Priority Findings

### M1 — Rebrand (NetDoctor) incomplete
- `docs/PRD.md` still titled NetworkConsole Lite; `Package.swift` product named `NetworkConsoleApp`; User-Agent hardcoded `NetworkConsoleLite/1.0` (`ReachabilityProber`); Application Support path `NetworkConsoleLite/timeline.jsonl`; support package filename prefix `NetworkConsoleLite-Support-*`; UserDefaults keys `networkConsoleLite.*`. Store name is already "NetDoctor: Network Diagnostics" (shown in ASC). → Unify to NetDoctor; treat old paths/keys as compatibility (migrate or document); read version from Bundle for User-Agent.

### M2 — Local signing config with personal identity committed (publish-blocking)
- `Config/ExportOptions.local.plist` is tracked in git and contains team ID `J84LGFK7GY`, signing cert "3rd Party Mac Developer Application: xukuo huang", provisioning profile name. → Move `.local` variant to `.gitignore`; keep only the export template.

### M3 — Doc status lag
- implementation-plan M4/M5 and appstore-checklist show unfinished items (screenshots, review notes, demo path) although artifacts exist (`docs/media/appstore/…`, `docs/media/review/index.html`, `PRIVACY.md`). → Sync checkboxes to actual artifacts.

### M4 — Redaction depth vs UI copy mismatch
- `SupportPackageExporter.redact()` redacts only `ssid`; public IPs (IPv4/IPv6), DNS servers, route gateway exported in full; timeline events raw (Chinese messages). UI claims auto-redaction of "Wi-Fi SSID and physical MAC". → Document policy (what stays is a product decision — IP/gateway have diagnostic value), align copy, keep timeline language-neutral (see H3).

## 4. Low Priority / Engineering Debt (L1–L8)

- L1: `DetailView.swift` (1675 lines), `Localization.swift` (1444 lines) oversized — split.
- L2: `DetailView.detectProvider` enumerates `172.16.`–`172.31.` — use bitmask/regex.
- L3: `AppModel.score` duplicate identical branches (lines 107-112) — redundant.
- L4: `SystemInterfaceCollector.collect()` returns `[]` if `getifaddrs` fails even when pathProvider has interface data — degrade gracefully.
- L5: `TimelineStore.append` writes file outside `NSLock` — potential JSONL interleaving under threads (mitigated by timestamp sorting); move write inside lock/serial queue for strict ordering.
- L6: Version sources diverge — `MARKETING_VERSION=1.1` / `CURRENT_PROJECT_VERSION=5` but User-Agent hardcodes `1.0` (merge with M1).
- L7: No CI config (e.g., GitHub Actions for `swift build && swift test`).
- L8: `docs/` process docs (`new-session-prompt.md`, `ui-dynamic-revamp-plan.md`, `ASO-Metadata-Strategy.md`) — archive or mark as historical.

## 5. Compliance Result (AGENTS.md hard rules) — all ✅
Read-only APIs only (NWPathMonitor/getifaddrs/SCDynamicStoreCopyValue); no Process/NSTask/Shell; minimal entitlements; no enterprise/hardcoded data; tests fully mocked; no telemetry (`PrivacyInfo.xcprivacy` clean); ASC token from env vars only.

## 6. Suggested Priority Order
1. Before next submission (publish-blocking): H2 SSID decision, M2 remove local config, M1 rebrand (at least docs + user-agent/paths).
2. v1.2 milestone: H1 (add 6-language keys + L10n completeness tests), H3 (typed enum codes), H4 (App-layer tests).
3. Continuous: L1–L8 debt + CI.

## 7. Antigravity Feedback & Alignment Consensus (2026-09-27)

1. **Agreement on Key Findings**: Fully agree with H1, M2, H3, M4, L2, L3, L5. M2 (security risk with personal identity) must be removed from git immediately. H3 typed enum refactor is adopted for v1.2. M4 copy mismatch (removing false promise of "physical MAC redaction") is adopted.
2. **Timing Difference on zh/en i18n**: The mixed Chinese/English issues in Settings, Overview pipeline, and Bento cards noted during audit have been completely resolved in commit `747ddef` (100% zh and en coverage verified).
3. **Correction on H2 (WiFi Entitlement)**: Do NOT apply for `com.apple.developer.networking.wifi-info`. It carries severe Apple App Review scrutiny for diagnostics apps. Policy adopted: retain current minimal sandbox entitlements, display graceful "Not available" fallback, align UI copy to prevent false promises.
4. **Correction on H1 (6-language coverage severity)**: App Store Connect lists only `English (US)`. The missing keys in non-en/zh languages gracefully fall back to English without review rejection. 8-language completeness is confirmed as a v1.2 quality milestone rather than a release blocker.
5. **Immutable Identifiers Red Line on M1**: Rebranding to `NetDoctor` must NEVER touch Bundle ID (`com.networkconsole.lite`), Apple ID (`6801707344`), SKU (`networkconsole-lite-0001`), or Team ID, because v1.1 is already live and distributable on App Store.