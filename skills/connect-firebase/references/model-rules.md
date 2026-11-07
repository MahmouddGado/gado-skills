# Complete-model checklist

Apply to every model of the module (and nested models it embeds). A model is "complete" only when all boxes pass.

## 1. Field coverage
- [ ] Every input in the module's forms maps to a model field (controllers, dropdowns, switches, date pickers, chips).
- [ ] Every field used in a Firestore query (`where`, `orderBy`, `arrayContains`) exists in the model and is written by `toMap`.
- [ ] Ownership/relation fields exist: `userId`/`ownerId`/`createdBy`, parent ids (`shopId`, `patientId`, …).
- [ ] Audit fields: `createdAt` (required), `updatedAt` (optional) unless the collection is a pure lookup table.
- [ ] Screens don't read keys that the model doesn't have (grep `data\['` in screens of the module).
- [ ] No password / passwordHash / token secrets in the model or `toMap`.

## 2. Serialization round-trip
- [ ] `toMap()/toJson()` writes every persisted field (computed getters excluded). Don't write `id` unless the project stores it inside the doc.
- [ ] `fromMap(map, id)` / `fromFirestore(doc)` reads every field written — names identical (watch case: `'City'` vs `'city'`).
- [ ] Tolerant parsing — never crash on missing/legacy data:
  - strings: `map['x'] as String? ?? ''` (or `?.toString()`)
  - numbers: `FsParse.toDouble(map['x'])`, `FsParse.toInt(map['x'])` (handles int/double/String/null)
  - bools: `map['x'] == true` or `as bool? ?? false`
  - dates: `FsParse.date(map['x'])` — accepts `Timestamp`, ISO `String`, `int` millis, `DateTime`, null
  - enums: `FsParse.enumByName(Enum.values, map['x'], fallback)` — never `firstWhere` without `orElse`
  - lists: `FsParse.stringList(map['x'])`; nested: `(map['x'] as List? ?? []).whereType<Map>().map((e) => Child.fromMap(Map<String, dynamic>.from(e))).toList()`
  - maps: `Map<String, dynamic>.from(map['x'] as Map? ?? {})`
  - GeoPoint: `map['loc'] is GeoPoint ? map['loc'] as GeoPoint : null`
- [ ] Write type == read type == partial update type (e.g. `update({'deliveredAt': ...})` must use the same format as `toMap`).
- [ ] Dates written in the project's format; Timestamp projects use `FieldValue.serverTimestamp()` for `createdAt` on create and `updatedAt` on every update (provide `toMapForCreate()`/`toMapForUpdate()` or a flag).

## 3. API surface
- [ ] `const` constructor with `required` for mandatory fields, sensible defaults for optional ones.
- [ ] `factory X.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) => X.fromMap(doc.data() ?? {}, doc.id);`
- [ ] `copyWith` covering all fields.
- [ ] `==`/`hashCode` (or Equatable) and `toString` if the project uses them.
- [ ] Class name doesn't collide with SDK types (`User` vs firebase_auth `User`) — if it does, import firebase_auth with `hide User` or `as fb`.

## 4. Model validation
Add `String? validate()` (return first error or null) — or `List<String> validate()` if the project prefers lists. Use the shared validators for format checks so messages match the forms:
```dart
String? validate() {
  return Validators.required(name, field: 'Name')
      ?? (email.isNotEmpty ? Validators.email(email) : null)
      ?? (price < 0 ? 'Price must be ≥ 0' : null)
      ?? (endDate.isBefore(startDate) ? 'End date must be after start date' : null)
      ?? (userId.isEmpty ? 'Missing owner' : null);
}
bool get isValid => validate() == null;
```
The service calls it before create/update: `final err = model.validate(); if (err != null) throw AppException(err);` (use the project's exception type; `ArgumentError`/`Exception` otherwise).

## 5. Verification grep (per model)
```bash
# keys written vs keys read — must match (ignoring id)
grep -oE "'[a-zA-Z_]+'\s*:" lib/models/x_model.dart | sort -u
grep -oE "map\['[a-zA-Z_]+'\]|json\['[a-zA-Z_]+'\]|data\['[a-zA-Z_]+'\]" lib/models/x_model.dart | sort -u
grep -nE "as Timestamp\)|as String,|as int,|firstWhere\([^)]*\)\s*[,;)]" lib/models/x_model.dart   # risky casts
```
