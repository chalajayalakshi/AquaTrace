# AquaTrace — Update Log

## 2026-11-09 14:52:22 +05:30 (Asia/Colombo, UTC+05:30) — Member 3 merged into test

### Completed
- Committed the form success-path QA as `e44187f` (`test(reporting): cover successful citizen submission`).
- Created local `test` from `upstream/test` (`883bf5e`) and merged `chalanima`; merge commit is `10f2fdc` (`merge citizen reporting into test`). The test branch retains later upstream history and includes the earlier reporting implementation.
- Pushed the merged branch to `origin/test`; the remote confirmed creation of the branch.
- Validated on the merged test branch: `flutter test` passed 23/23; `flutter analyze` reported no Dart issues, with only the pre-existing missing `assets/icons/` warning.
- `flutter build web` passed before switching branches, with the same missing-asset warning and a non-blocking wasm dry-run notice.

### Remaining / blockers
- Live Firebase Storage/Firestore verification still requires Storage to be enabled and an authenticated Firebase citizen account. Camera and GPS permission prompts still require a physical device or emulator.

## 2026-11-09 14:50:52 +05:30 (Asia/Colombo, UTC+05:30) — Member 3 success-path QA

### Completed
- Added a widget-level happy-path test for the full citizen report form using injected GPS/photo inputs, a restored demo-citizen identity, and a fake persistence gateway.
- Verified fault type, description, severity, address, confirmed numeric coordinates, evidence URL, authenticated reporter UID, UTC creation time, `pending` status, upload-before-create order, repository visibility, and successful return from the form.
- Updated the test harness to avoid a fake-clock deadlock from the demo sign-in delay and to model the IO `XFile` filename via its path.

### Checks
| Command | Result |
|---------|--------|
| `dart format test/report_submission_test.dart` | Pass. |
| `flutter test` | Pass — 23/23 after formatting. |
| `flutter analyze` | No reporting-code issues; existing warning: configured asset directory `assets/icons/` is missing. |
| `flutter build web` | Pass — `build/web` generated; existing missing `assets/icons/` warning and non-blocking wasm dry-run notice. |
| `get_errors` on `test/report_submission_test.dart` | No errors. |

### Remaining / blockers
- Live Storage upload / Firestore persistence still needs an enabled Firebase Storage bucket and a real authenticated citizen account; demo identities are intentionally blocked from cloud submissions.
- Real camera/location permission prompts need a mobile device or emulator.
- `upstream/test` was at `883bf5e` and already contained the earlier reporting commit `f1472f6`; the success-path test and update entry were merged into the local `test` branch.


## 2026-11-09 12:48:59 +05:30 (Asia/Colombo, UTC+05:30) — Member 3 citizen fault reporting

### Completed
- Replaced the citizen home reporting placeholder with a routed fault-report form for fault type, description, severity, street/landmark, GPS coordinates, and evidence photo.
- Added camera/gallery selection, image type/size checks, location permission/GPS error states, coordinate review/confirmation, required-field validation, and protection against duplicate taps or leaving during submission.
- Added Firebase Storage evidence upload and idempotent Firestore report creation using the agreed `ReportModel` fields, authenticated reporter UID, UUID-based report ID, numeric coordinates, UTC creation time, `pending` initial status, and evidence download URL.
- Added report snapshot synchronization to the shared repository and owner-restricted `storage.rules` configuration.
- Added focused success, validation, permission, picker cancellation, upload failure, Firestore failure, and duplicate-submission tests.
- Files changed: `firebase.json`, `lib/core/navigation/app_router.dart`, `lib/core/services/data_repository.dart`, `lib/core/services/report_submission_gateway.dart`, `lib/features/citizen/presentation/citizen_home_view.dart`, `lib/features/reports/presentation/citizen_report_form_screen.dart`, `lib/features/reports/services/citizen_report_input_provider.dart`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `pubspec.yaml`, `pubspec.lock`, `storage.rules`, `test/report_submission_test.dart`.

### Checks
| Command | Result |
|---------|--------|
| `dart format lib test` | Pass — formatted reporting changes. |
| `flutter analyze` | No Dart issues; existing warning: configured asset directory `assets/icons/` is missing. |
| `flutter test test/report_submission_test.dart` | Pass — 12/12. |
| `flutter test` | Pass — 22/22. |
| `flutter build web` | Pass — `build/web` generated; existing missing `assets/icons/` warning and non-blocking wasm dry-run notice. |
| Browser smoke (`http://localhost:5173/#/reports/new`) | Pass — form rendered at desktop/mobile sizes; empty submit showed required-field errors. |

### Outstanding / blockers
- Live Storage upload and Firestore persistence were not verified: Firebase Storage is not enabled/configured for the project in this environment, and no authenticated Firebase citizen account was available. Demo-role identities are intentionally rejected by the submission gateway. Deploy/enable the owner-scoped Storage rules only after the project Storage bucket is enabled and authorized.
- Camera and physical GPS permission behavior is covered through injected platform-provider tests; no mobile device/emulator was available for a physical permission prompt test.
- Existing `assets/icons/` folder is missing although declared in `pubspec.yaml`; analysis/build report this warning.
- Citizen-home shared report-card background/overflow console warnings observed during smoke test are outside this module's changes.
- Exact checks: `dart format lib test`; `flutter analyze`; `flutter test test/report_submission_test.dart`; `flutter test`; `flutter build web`.

## 2026-11-03 18:29:44 +0530 (UTC+0530) — Member 1 remaining cloud hardening complete

### Completed
- Deployed `firestore.rules` to `aquatrace-92e2e` (compiled clean; unused `isStaff` removed).
- Enabled Authentication **Email/Password**.
- Applied Google Cloud API key **application restrictions**:
  - Android: `com.aquatrace.aquatrace` + debug SHA-1
  - iOS: bundle `com.aquatrace.aquatrace`
  - Browser: localhost + Firebase Hosting referrers
- Seeded staff Auth users + `/users/{uid}` docs: `admin@aquatrace.lk` (admin), `tech@aquatrace.lk` (technician).
- Added `scripts/member1_cloud_hardening.py`; gitignored `scripts/.seed_credentials.local.json`.
- Verified: `flutter analyze` clean; `flutter test` **10/10**.

### Not done (out of automated scope / intentional)
- GitHub Secret Scanning alerts **not** auto-dismissed (expected client keys — dismiss manually as false positive if desired).
- API keys **not rotated** (not required; restrictions applied instead).
- Release Android SHA-1 not added yet (debug only).
- Google/Apple OAuth still stubbed.

---

## 2026-11-03 18:12:33 +0530 (UTC+0530) — Member 1 prompts 1A–1C complete

### Completed tasks (Member 1)
- **1A:** Confirmed feature-first foundation, theme/widgets/routing/README remain intact; documented Firebase project + OAuth/setup gaps.
- **1B:** Public registration hard-locked to **citizen**; removed privileged role ChoiceChips from `RegisterScreen`.
- **1B:** `AuthService.updateProfile` patches only safe fields (never `role`/`email`/`uid`/`employeeId`).
- **1B:** Documented role security model + `firestore.rules` in README §7; Google/Apple remain graceful stubs with setup notes.
- **1C:** Added `docs/MEMBER1_HANDOFF.md` for Members 2–8; reviewed init/auth/routing contracts.

### Files / modules changed
- `lib/core/services/auth_service.dart`
- `lib/features/auth/providers/auth_provider.dart`
- `lib/features/auth/presentation/register_screen.dart`
- `lib/features/auth/presentation/login_screen.dart`
- `test/widget_test.dart`
- `README.md`
- `docs/MEMBER1_HANDOFF.md`
- `firestore.rules` / `firestore.indexes.json` / `firebase.json` (from prior rules work; included in this handoff)

### Tests / commands
| Command | Result |
|---------|--------|
| `dart format lib test` | Pass |
| `flutter analyze` | Pass — no issues |
| `flutter test` | Pass — **10/10** |
| `flutter run -d chrome` | Pass — debug service connected; Flutter run key commands shown |

### Remaining / blockers (not Member 1 feature scope)
- Deploy `firestore.rules` only when explicitly authorized.
- Enable Email/Password + create Firestore DB in Console if not already.
- Seed first admin/technician via Admin SDK.
- Members 3–8 still own Firestore sync for reports, Storage, FCM, verification Functions.
- macOS Firebase SPM cold build can be slow; Chrome smoke used for launch verification.

---

## 2026-11-03 18:03:41 +0530 (UTC+0530) — Firestore security rules (proposed, not deployed)

### Completed tasks
- Reviewed README contracts, models, `AuthService`, `DataRepository`, register UI, and UI verify/dispute references.
- Added production-oriented `firestore.rules` covering users, notifications, reports, activity, verifications, disputes.
- Wired `firebase.json` → `firestore.rules` + empty `firestore.indexes.json`.
- Documented required backend/client changes (force citizen registration, Admin SDK role seed, Cloud Functions for counters).

### Explicitly not done
- **No deploy** to Firebase Console / `aquatrace-92e2e`.
- Console security rules **unchanged**.
- Emulator syntax load blocked: Java runtime missing on this machine (`firebase emulators:exec` failed locating JRE).

### Validate later
1. Install a JRE, then `firebase emulators:exec --only firestore --project aquatrace-92e2e "echo ok"`.
2. Or paste `firestore.rules` into Console → Firestore → Rules Playground.
3. Deploy only when authorized: `firebase deploy --only firestore:rules --project aquatrace-92e2e`.

---

## 2026-11-03 15:08:14 +0530 (UTC+0530) — Firebase project configuration

### Completed tasks
- Installed Firebase CLI (`15.34.2`) and FlutterFire CLI (`1.4.1`).
- Authenticated Firebase CLI as `geenodsaniru@gmail.com`.
- Connected the Flutter app to the **existing** Firebase project **AquaTrace** (`aquatrace-92e2e`) — no new Firebase project created.
- Registered Firebase apps for Android, iOS, and Web (macOS reuses the iOS app / same bundle id `com.aquatrace.aquatrace`).
- Generated real `lib/core/config/firebase_options.dart` for project `aquatrace-92e2e` (kept `DefaultFirebaseOptions.isConfigured` for the existing `FirebaseService` architecture).
- Added/confirmed native client configs:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
  - `macos/Runner/GoogleService-Info.plist`
- Confirmed Android Google Services Gradle plugin wiring in `android/settings.gradle.kts` and `android/app/build.gradle.kts` (FlutterFire partial apply).
- Added `.firebaserc` (default `aquatrace-92e2e`) and `firebase.json` FlutterFire platform map.
- Hardened `.gitignore` for service-account / private-key patterns (no admin SDK JSON committed).
- Preserved existing `FirebaseService.initialize()` startup flow in `lib/main.dart` (still uses `DefaultFirebaseOptions`).
- Fixed demo-role widget test navigation stubbing so auth assertions do not mount role shells.
- Added unit coverage asserting Firebase options target `aquatrace-92e2e`.

### Configuration changes
| Item | Value |
|------|--------|
| Firebase project ID | `aquatrace-92e2e` |
| Android applicationId | `com.aquatrace.aquatrace` |
| iOS / macOS bundle ID | `com.aquatrace.aquatrace` |
| Android app ID | `1:298509402653:android:db2fc54fac90b6b5b47cf4` |
| iOS app ID | `1:298509402653:ios:e62995a1bb869e46b47cf4` |
| Web app ID | `1:298509402653:web:cca7d1291ccb34d9b47cf4` |

### Firebase services configured in the app (dependencies / init)
- **Firebase Core** — configured and initialized via `FirebaseService` + generated options.
- **Firebase Auth** / **Cloud Firestore** — already depended on in `pubspec.yaml` and used by `AuthService` when `FirebaseService.isRealFirebase == true`.
- **Not enabled/deployed in this run:** Firebase Storage rules, FCM, Analytics product toggles, unrestricted Firestore/Storage security rules (intentionally avoided).

### Tests and build results
| Check | Result |
|-------|--------|
| `dart format lib test` | Pass (no formatting changes required) |
| `flutter analyze` | Pass — no issues found |
| `flutter test` | Pass — **8/8** tests |
| `flutter build apk --debug` | Pass — `build/app/outputs/flutter-apk/app-debug.apk` |
| macOS / web debug builds | Attempted; stopped after long Firebase iOS SPM / toolchain fetch with no completion in-session. Android APK remains the verified native build. |
| Firebase options unit test | Pass — project/app IDs match `aquatrace-92e2e` |
| Runtime `Firebase.initializeApp` console log | Wired in `FirebaseService` (logs projectId/appId). Full device/emulator sign-in against live Auth/Firestore still blocked until Console products are enabled (see remaining steps). |

### Notes / environment blockers during FlutterFire CLI
- `flutterfire configure` registered apps and wrote native config files, but failed on Ruby `xcodeproj` gem dependency chain (`rexml`/`nkf`) under Homebrew Ruby 4.0.
- Completed `firebase_options.dart` and remaining wiring from `firebase apps:sdkconfig` outputs for the registered apps (same project, no duplicate Firebase project).

### Remaining manual steps (Firebase Console / Google Cloud)
1. **Enable Email/Password** in Firebase Authentication → Sign-in method.
2. **Enable Cloud Firestore API** for `aquatrace-92e2e` (CLI reported API unused/disabled: enable at Google Cloud Console → Firestore API, then create the Firestore database).
3. Apply **locked-down** Firestore security rules (do **not** use open `allow read, write: if true`).
4. Optionally enable **Storage** / **FCM** later when Members 3/8 need them — not required for Core init.
5. Optionally add `GoogleService-Info.plist` to the Xcode target membership if native iOS/macOS tooling requires it beyond Dart `Firebase.initializeApp(options:)` (Dart options path is active).
6. Create at least one real Auth user + `/users/{uid}` profile doc with a valid `role` for end-to-end sign-in testing outside demo buttons.

### Git
- Target branch: `geenod` (not `main`).
