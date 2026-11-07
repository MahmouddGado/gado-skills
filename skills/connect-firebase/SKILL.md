---
name: connect-firebase
description: Wire ONE module of a Flutter app to Firebase (Auth + Cloud Firestore) end to end — complete and validate the model(s), create or fix the service/repository, connect it through the project's state layer (Provider / Riverpod / Bloc / setState — follows the project, defaults to Provider), connect the screens (replace mock data, fake saves), and add full TextFormField validation to every form in the module. Detects and follows the target project's own conventions. Invoke as "/connect-firebase <Module> [project-path]" (e.g. Auth, Medication, Alerts, Shop, Reminder, Report).
argument-hint: <Module> [project-path]
---

# connect-firebase

Connect a module of a Flutter app to Firebase: **Model ⇄ Service/Repository ⇄ State layer ⇄ Screens**,
with complete, validated models and validated forms. `$ARGUMENTS` = `<Module> [project-path]`.

Scope: **Firebase Auth + Cloud Firestore** only. Do not add or change file storage (Firebase Storage,
Supabase, Flask upload servers) — if the module uploads files, keep the project's existing upload path and
store the returned URL/path in the model.

Supporting files (read when the step says so — paths relative to this skill dir, e.g. `~/.claude/skills/connect-firebase/`):
- `references/conventions-detection.md` — how to detect the project's style (+ hints table of known projects)
- `references/model-rules.md` — the "complete model" checklist
- `references/validators.md` — canonical validator set, messages (AR/EN), form rules
- `references/pitfalls.md` — bugs seen in real projects; check every one
- `templates/*.dart.tmpl` — starting points. **Adapt them to the project's naming/style; never paste blindly.**

## Golden rules
1. **Follow the project.** Match its state management, model method names (`fromJson` vs `fromMap`),
   id handling, date format, folder layout, file naming, UI language (Arabic/English), input widgets.
2. **Reuse before creating.** If a service, provider, validator or widget exists, wire/extend it. Never
   create a second service for the same collection.
3. **No fake success.** A success snackbar/dialog/navigation may only run after the awaited write succeeded.
4. **Never store passwords** (plain or "hash") in Firestore. User docs live at `users/{uid}` via `doc(uid).set`.
5. **Show the module map before editing** (Step 3) and keep edits inside the module + shared files
   (validators, firestore_safe helpers, DI registration, main.dart init).
6. Do not deploy rules/indexes, do not run `flutterfire configure` yourself (needs the user's login).

## Step 0 — Locate & parse
1. Split `$ARGUMENTS`: first token = module name; the rest (if any) = project path.
2. Find the Flutter root: nearest `pubspec.yaml` containing `sdk: flutter` at or under the given path / cwd.
   Search with pruning: `find <dir> -maxdepth 5 \( -name build -o -name .dart_tool -o -name node_modules -o -name .git -o -name zips \) -prune -o -name pubspec.yaml -print`.
   If several roots match (duplicate copies like `v1.0.0/` vs `full_code/`, `fullcode/` vs older copy),
   list them and ask which one. Confirm the root before continuing.
3. Create a todo list with Steps 1–10.

## Step 1 — Firebase setup check (check & guide)
- `pubspec.yaml`: need `firebase_core`, `firebase_auth`, `cloud_firestore` (+ `provider` if Step 2 picks
  Provider for a project without state management). Missing → `flutter pub add <pkg>`. **Stay on the
  project's existing Firebase major line** (core 3.x ↔ auth 5.x ↔ firestore 5.x; core 4.x ↔ auth 6.x ↔
  firestore 6.x) — if one package exists, pick the compatible versions of the others.
- `firebase_options.dart` (usually `lib/`, sometimes `lib/configuration/firebase/`), `android/app/google-services.json`,
  `firebase.json`. Warn (don't fail) if `ios/Runner/GoogleService-Info.plist` is missing.
- `main.dart`: must have `WidgetsFlutterBinding.ensureInitialized();` and
  `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);` before `runApp`, or an
  existing bootstrap that does it (e.g. `FirebaseBootstrap.initialize()`). Add if missing. If init is
  wrapped in a try/catch that swallows errors, make it at least `debugPrint` + rethrow in debug.
- **If `firebase_options.dart` is missing:** tell the user to run `! dart pub global activate flutterfire_cli`
  then `! flutterfire configure` in the project root, and continue writing code that will compile once it exists.

## Step 2 — Detect conventions
Read `references/conventions-detection.md` and fill in this summary (print it to the user):
```
State mgmt      : provider | riverpod | bloc/cubit | getx | none(→ Provider)
Model style     : fromJson/toJson | fromMap/toMap | fromFirestore/toFirestore ; id: passed | inside doc ; copyWith: y/n ; ==: y/n
Dates           : Timestamp | ISO string   (keep it; always READ both)
Service style   : per-collection | god-service | singleton | locator(sl) | interface+impl(+mock) ; collection constants: <file|none>
Validators      : <path + class/method naming | none> ; messages: inline | AppStrings | l10n keys ; lib: form_builder_validators?
Input widget    : <CustomTextField/AppTextField/... | TextFormField>
UI language     : Arabic | English
Routing         : go_router | named routes | Navigator.push
```

## Step 3 — Module map (show before editing)
Find every file touching the module (case-insensitive grep for the module name, its plural, snake_case,
collection name): models, services/repositories, providers/notifiers/cubits, screens, dialogs/bottom
sheets, widgets, mock/fixed data (`fixed_data/`, `mock_*`, `dummy_*`, `DummyData`, `MockData`, `Mock*Service`,
`Future.delayed` fakes), DI registration (`MultiProvider`, `providers.dart`, service locator), routes.
For **Auth**: auth service, user model, login/register/forgot/profile/edit-profile screens, auth wrapper/guard/splash.

Print a table: `file | role | status` where status ∈ `OK`, `mock`, `missing`, `unwired`, `fake-save`,
`stream-in-build`, `no-validation`, `incomplete-model`. Then proceed (ask only if the module name matched
nothing or matched two unrelated features).

## Step 4 — Complete & validate the model(s)
Follow `references/model-rules.md`. In short:
1. Build the field list from: existing model + every form field / controller in the module's screens +
   every field used in Firestore queries (`where`, `orderBy`) and in rules. Add missing fields.
2. Every field round-trips: written by `toMap/toJson`, read by `fromMap/fromJson` with tolerant parsing
   (use/create the shared helpers from `templates/firestore_safe.dart.tmpl` — `FsParse.date`, `.toDouble`,
   `.toInt`, `.enumByName`, `.stringList`, `.map`). No hard `as Timestamp` / `as String` on nullable data.
3. `id` comes from `doc.id`; add `fromFirestore(DocumentSnapshot)` convenience.
4. `createdAt`/`updatedAt`: written with the project's date format; for Timestamp projects use
   `FieldValue.serverTimestamp()` on create/update.
5. Add `copyWith` (always), `==`/`hashCode`/`toString` if the project's models have them.
6. Add model validation: `String? validate()` returning the first problem (or `null`), using the shared
   validators for format checks plus business rules (ranges, required relations like `userId` non-empty,
   end ≥ start). The service calls it before every create/update and throws on failure.
7. Verify write/read type parity for every field (same type written in `toMap` AND in partial `update({...})` calls).

## Step 5 — Service / repository
- Existing service for the collection → fix and use it (don't duplicate). Unused real service + provider
  wired to a mock → switch the wiring to the real one.
- Otherwise create from `templates/firestore_service.dart.tmpl`, in the project's style (interface + impl
  if the project uses that; singleton/locator registration if it uses that). Must provide:
  `create` (returns id; uses `doc()` id when model id empty), `getById`, `getAll`/filtered `get`, `watchAll`
  and `watchBy<Field>` streams (user-scoped where relevant), `update` (full model) and `updateFields`,
  `delete`, `count()` aggregate when counts are shown. Typed collection, collection-name constant (reuse
  `FirestoreCollections`-style file if present), `model.validate()` before writes, `FirebaseException` →
  friendly message in the UI language (rethrow as the project's exception type).
- **Auth module:** use `templates/auth_service.dart.tmpl`: `authStateChanges`, `currentUser`,
  `signIn`, `signUp` (creates `users/{uid}` with ALL profile fields from the form, never the password),
  `signOut`, `sendPasswordReset`, `loadCurrentUserModel`, `updateProfile`, optional `changePassword`
  (reauthenticate first), `FirebaseAuthException` code → message map.

## Step 6 — State layer
- **Provider:** `templates/provider.dart.tmpl` — ChangeNotifier holding the service, `items`, `isLoading`,
  `isSaving`, `error`, `StreamSubscription` started by `listen(...)`/`bind(userId)`, CRUD methods that
  `await` the service and return `bool`/throw, `dispose()` cancels. Register in `MultiProvider`
  (`ChangeNotifierProxyProvider` if it depends on auth).
- **Riverpod:** `templates/riverpod.dart.tmpl` — service `Provider`, `StreamProvider(.family/.autoDispose)`
  for reads, `StateNotifier`/`AsyncNotifier` (match the project) for writes. Replace `Mock*` repos in DI.
- **Bloc/Cubit:** Cubit with `Loading/Loaded/Error/Saving` states, stream subscription closed in `close()`.
- **setState-only projects:** keep it, but hold service + stream in `State` fields created in `initState`
  (never inside `build`) and use `StreamBuilder`.

## Step 7 — Screens
- List screens: read from the state layer; handle loading / error (with retry) / empty / data.
- Remove mock/dummy/fixed data usage for this module (delete the mock file only if nothing else imports it).
- Forms (screens, dialogs, bottom sheets) — follow `references/validators.md` and `templates/form_screen.dart.tmpl`:
  `Form` + `GlobalKey<FormState>`, every input is a `TextFormField` (or the project's input widget) with a
  validator, `keyboardType`, `inputFormatters` (digits/decimal/phone), `textInputAction`, `maxLength` where
  sensible, `autovalidateMode: AutovalidateMode.onUserInteraction`; dropdowns/date pickers use
  `DropdownButtonFormField` / `FormField` with validators too.
- Submit: `if (!_formKey.currentState!.validate()) return;` → build model → `await` save → `if (!mounted) return;`
  → success feedback/navigation; catch → show the error message. Disable the button and show a spinner
  while saving. Edit mode prefills controllers from the model and calls `update`.
- Remove every fake save (success UI with no write, `Future.delayed` placeholders, `onPressed: () {}` on
  save buttons in the module).
- Dispose all controllers.

## Step 8 — Validators file
Reuse the project's validators file and naming (extend it with what's missing). If none exists, create one
from `templates/validators.dart.tmpl` at the project's conventional place (`lib/core/utils/validators.dart`,
or `lib/utils/validators.dart` if `lib/utils/` exists). If `form_builder_validators` is already used,
build on it instead. Messages in the project's UI language (use its `AppStrings`/l10n if it has one).
Replace inline duplicates **in this module** with the shared validators.

## Step 9 — Firestore rules & indexes (suggest only)
If `firestore.rules` exists, propose a block (if it doesn't — most projects have none — propose creating
`firestore.rules` + `firestore.indexes.json` and adding them to `firebase.json` under `"firestore"`). Propose a block for the module's collection (auth required; owner-only
writes via `request.auth.uid == resource.data.userId`; admin role check via `get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role` if the project has roles;
basic field validation mirroring `model.validate()`). Propose `firestore.indexes.json` entries for each
`where(A) + orderBy(B)` query. Show diffs; tell the user to run `! firebase deploy --only firestore:rules,firestore:indexes`.
Never deploy yourself.

## Step 10 — Verify & report
1. `flutter pub get` then `dart format <changed files>` and `flutter analyze` — fix every **new** error/warning
   you introduced (report pre-existing ones separately, don't mass-fix unrelated code).
2. Greps for the module: no remaining `Mock`/`Dummy`/`fixed_data` imports; no `TextField(` without a
   validator inside a form; every model field name appears in both `toMap/toJson` and `fromMap/fromJson`;
   no `Service()` / `.snapshots()` / `.get()` constructed inside a `build` method.
3. Check every item of `references/pitfalls.md` against the touched files.
4. Final report:
   - Conventions summary (Step 2)
   - Table: file → created/changed → what
   - Models: fields added, parse fixes, `validate()` rules
   - Forms: screen → fields → validators applied
   - Leftovers / user actions: `flutterfire configure`, rules/index deploy, iOS plist, pre-existing analyzer issues,
     things intentionally left (e.g. storage on Supabase).
