# Pitfalls found in real projects — check every one on the touched files

## Security / data integrity
- [ ] **Passwords in Firestore** (Pet Connect writes `'password'`, SMW writes `passwordHash`). Remove from model/toMap; Auth owns credentials.
- [ ] **User docs via `.add()`** (random id) then `where('id', isEqualTo: uid)` lookups. Use `collection('users').doc(uid).set(...)` and `doc(uid).get()`.
- [ ] **Sign-up drops fields** (DermaCare `signUp` receives phone/birthDate/gender and writes `null`). Every form field must reach the user doc.
- [ ] Fallback ids like `'guest'` / `'unknown_user'` written as owner. Require an authenticated uid or block the action.
- [ ] Hard-coded keys/URLs (Supabase anon key, LAN IP `http://192.168.x.x:5000`, stray leading space `' http://…'`). Don't fix storage, but flag them in the report.

## Model / parsing
- [ ] Hard casts `json['createdAt'] as Timestamp` → crash on null/ISO. Use `FsParse.date`.
- [ ] `DateTime.parse(json['x'] as String)` → crash on Timestamp/null.
- [ ] `Enum.values.firstWhere((e) => e.name == x)` without `orElse`.
- [ ] Write/read mismatch: `toMap` writes `DateTime`/Timestamp but a partial `update({'x': DateTime.now().toIso8601String()})` writes String (Friend of the Earth `municipalityResponseAt`, bisha_shield `deliveredAt`).
- [ ] `orderBy` on ISO-string dates is OK only if ALL docs use the same ISO format; mixing Timestamp and String breaks ordering.
- [ ] Models with no serialization at all (Fake News History/Detection; Pet Connect User/Message).
- [ ] Mixed-case / snake_case keys (`'City'`, `eye_color`, `late`/`long` for lat/lng) — keep existing keys for data compatibility, but make read == write.
- [ ] Model class named `User` colliding with firebase_auth `User` → `import 'package:firebase_auth/firebase_auth.dart' hide User;` or prefix.

## Services / wiring
- [ ] Provider/notifier wired to `Mock*Service` while a real Firestore service exists (bisha_shield alerts/admin/history, Wiqayah messages/sms/preferences, Fake News history/admin).
- [ ] Real services never used by any screen (car_mazad ImageUpload/Search/Report, DermaCare ProductRecommendation/AdminReport/ImageRecord, bisha_shield FirestoreService).
- [ ] Services that navigate or show snackbars with a `BuildContext` (Pet Connect `Auth.register(ctx)`) → return result/throw; screens navigate.
- [ ] Errors swallowed (`catch (e) { print(e); }`, `catchError((_) {})`, `return false` with no message) → surface a message.
- [ ] Services throwing plain `String` (`throw 'Failed…'`) → throw `Exception`/project exception type (inside the module).
- [ ] Counting by downloading the whole collection (`snapshots().map((s) => s.docs.length)`) → `collection.count().get()` (or keep stream only if live count really needed and collection is small).
- [ ] `Firebase.initializeApp` inside a try/catch that swallows errors.
- [ ] `where(A) + orderBy(B)` queries without a composite index → add to `firestore.indexes.json` suggestion.

## Screens
- [ ] **Fake saves**: success dialog/snackbar with no write (Smart Health add/edit responder, feedback; bisha_shield profile `Future.delayed`; Smart Menu "Send"; `onPressed: () {}`).
- [ ] Writes not awaited before success UI (`_service.update(...)` then snackbar).
- [ ] Stream/Future created inside `build` (`StreamBuilder(stream: XService().watch())`, `FutureBuilder(future: svc.get())`) → resubscribes on every rebuild. Create once in `initState`/provider.
- [ ] Services instantiated in `build` (`final s = XService();`).
- [ ] Mock/dummy/fixed data driving a screen (`DummyData.products`, `mockTickets`, `MockMeals`, `FixedData`, hard-coded "94%" stats).
- [ ] Plain `TextField` in dialogs/sheets with no `Form`/validator; `if (ctrl.text.isEmpty) return;` as the only check.
- [ ] `double.tryParse(...) ?? 0` silently storing zeros.
- [ ] Validators using `v!` force-unwrap; weakly typed `String? Function(dynamic)`; misspelled params (`validetor`) — fix the widget signature to `FormFieldValidator<String>?` if touched.
- [ ] Email checked only with `contains('@')`; phone never validated.
- [ ] Login enforcing the full password-strength rule (locks out older accounts) — login = required only.
- [ ] Missing `mounted` checks after `await`; controllers not disposed.
