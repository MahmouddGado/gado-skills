# Detecting a project's conventions

Always detect from the real code — the table at the bottom is only a hint.

## State management
| Signal (pubspec + usage) | Result |
|---|---|
| `flutter_riverpod`/`hooks_riverpod` AND `ConsumerWidget`/`ref.watch` used in lib/ | Riverpod (check `StateNotifier` vs `Notifier/AsyncNotifier` vs `StreamProvider`) |
| `flutter_riverpod` declared but only `ProviderScope` used | treat as **none** (setState) unless the user wants Riverpod |
| `flutter_bloc`/`bloc` + `Cubit`/`Bloc` classes | Bloc/Cubit |
| `get` + `GetxController`/`Obx` | GetX |
| `provider` + `ChangeNotifier` classes | Provider |
| `provider` used only as `Provider<Service>` (DI, no ChangeNotifier) | Provider — add a ChangeNotifier for the module, keep DI style for the service |
| none of the above | **Provider** (add `provider` dep, wrap app in `MultiProvider`) |

Commands:
```bash
grep -E "^\s+(provider|flutter_riverpod|hooks_riverpod|riverpod_annotation|flutter_bloc|bloc|get|get_it|form_builder_validators|flutter_form_builder|firebase_core|firebase_auth|cloud_firestore):" pubspec.yaml
grep -rlE "extends (ChangeNotifier|StateNotifier|Notifier|AsyncNotifier|Cubit|Bloc|GetxController)|with ChangeNotifier" lib | head
grep -rn "MultiProvider\|ProviderScope\|MultiBlocProvider\|GetMaterialApp" lib | head
```

## Models
- Method names: `grep -rhoE "factory \w+\.(from\w+)" lib/models lib/**/models | sort | uniq -c`
- Id: `fromMap(map, id)` / `fromJson(json, id)` (id passed) vs `json['id']` (stored inside). Prefer passing `doc.id`; if the project stores id inside, keep writing it but still read `doc.id` as the source of truth.
- Dates: `toIso8601String()` → ISO; `Timestamp.fromDate`/`serverTimestamp` → Timestamp. Mixed → pick the majority for writes, read both.
- Extras: `copyWith`, `==`/`hashCode`, `Equatable`, `toString`, enums via `.name`.
- Model file naming: `x_model.dart` vs `x.dart`; class `XModel` vs `X`.

## Services
- Per-collection class (`x_service.dart`) / one `firestore_service.dart` god-service / singleton (`static final _instance`) / locator (`sl.x`, `get_it`) / abstract `XRepository` + `FirestoreXRepository` (+ `MockXRepository`).
- Collection-name constants: look for `FirestoreCollections`, `AppConstants.xCollection`, `kXCollection`.
- Error style: throws `Exception`, custom `AppException`/`Failure`, plain String (fix to Exception only inside the module), returns bool.
- If the project is a god-service, add the module's methods to it **only** if it's small; otherwise create a per-collection service and mention it.

## Validators & inputs
```bash
grep -rlE "class (Validators|AppValidators|Validation|\w+Validator)\b" lib
grep -rn "validator:" lib | wc -l ; grep -rn "TextField(" lib | wc -l
grep -rlE "class \w*(TextField|Input|FormField)\w* extends" lib/widgets lib/core 2>/dev/null
```
Note the method naming (`Validators.email` vs `validateEmail` vs `EmailValidator.validate`) and the message source (`AppStrings.x`, l10n keys like `'requiredField'` translated in the widget, inline text).

## UI language
Count Arabic chars in screen strings: `grep -rP "[\x{0600}-\x{06FF}]" lib/screens | wc -l` vs English `Text('…')`. Use the dominant one for validator/error messages.

## Routing
`go_router` (`GoRoute`), `onGenerateRoute`, `routes: {}` map, or plain `Navigator.push` — add new screens the same way.

## Hint table (scan of 2025_2026_secend_term, Oct 2026)
| Project | State | Model style | Dates | Validators |
|---|---|---|---|---|
| 00 Allergens | provider | toMap/fromMap/fromFirestore/copyWith/== | Timestamp | inline |
| 01 AR Tourism | riverpod declared, unused → setState | fromJson/toJson/copyWith | ISO | lib/core/utils/validators.dart |
| 02 MedPredict | riverpod (StreamProvider.family, providers at bottom of service files) | toMap/fromMap(map,id)/copyWith | ISO | inline |
| 03 Fake News | riverpod StateNotifier | only UserModel serialized | ISO | lib/core/utils/validators.dart (form_builder_validators) |
| 04 My Plant | none (setState) | fromJson/toJson/copyWith | ISO (+Timestamp user) | lib/core/validation.dart |
| 05 Depression | provider (auth only) | fromFirestore/toFirestore | Timestamp | inline |
| 07 Pet Connect | none | weak fromjson, no toJson | — | inline (`validetor`) |
| 08 Friend of Earth | provider as DI; Firebase 3.x/5.x | fromMap/toMap | mixed | lib/utils/validators.dart |
| 09 DermaCare | provider | fromJson/toJson | ISO | lib/config/validators.dart (l10n keys) |
| 10 SMW | none (singletons) | toJson/fromJson/fromFirestore | Timestamp | lib/utils/validators.dart |
| 11 Wiqayah | riverpod + repo interfaces + mocks; Firebase 3.x/5.x | fromJson/toJson/copyWith/== | ISO | lib/utils/validators/*.dart |
| 13 My Memory | provider | toMap/fromMap(map,id) | Timestamp | inline |
| 14 Smart Menu | provider (auth) + god FirestoreService | toJson/fromJson/copyWith | ISO | none |
| 15 Smart Line | provider | fromMap(map,id)/toMap/copyWith | Timestamp | inline (Arabic) |
| 17 car_mazad | none (StreamBuilder) | toMap/fromMap | ISO | lib/core/validators.dart (Arabic) |
| 21 bisha_shield | riverpod StateNotifier + mock services; Firebase 3.x/5.x | fromJson(json,id)/toJson/copyWith | Timestamp (hard cast) | empty lib/core/validators/ |
| 22 Smart Health | provider + `sl` locator | fromJson/toJson/copyWith/== | ISO | lib/utils/validators.dart (AppStrings) |
