# Validators & form rules

## Canonical validator set
Every project must end up with (under its own naming): `required`, `email`, `password`, `confirmPassword`,
`phone`, `name`, `minLength`, `maxLength`, `number` (with optional min/max), `integer` (min/max), `url`,
`otp`, `date`/`notNull` (for pickers/dropdowns), `compose` (chain several).
Template: `templates/validators.dart.tmpl` (functions return `String?`; factories return `FormFieldValidator<String>`).

### Regexes
| Rule | Regex / logic |
|---|---|
| Email | `^[\w.+-]+@([\w-]+\.)+[A-Za-z]{2,}$` on trimmed value |
| Password (default) | ≥ 8 chars, ≥1 letter, ≥1 digit. Keep a stricter project rule if it exists (upper/lower/special). Login screens only check `required` (don't block old accounts). |
| Phone – generic | `^\+?[0-9]{8,15}$` after removing spaces/dashes |
| Phone – Saudi | `^(05\d{8}|\+9665\d{8}|9665\d{8})$` |
| Phone – Egypt | `^(01[0125]\d{8}|\+201[0125]\d{8})$` |
| Name | trimmed length 2–50, letters (Arabic/Latin), spaces, `.'-` : `^[\p{L} .'-]+$` (unicode: true) |
| URL | `Uri.tryParse(v)` with scheme http/https and non-empty host |
| OTP | exactly N digits `^\d{N}$` |
| Number | `double.tryParse(v.replaceAll(',', '.'))` + range |
Pick the phone variant from the project (Saudi code `+966` hints → Saudi; `+20`/`01x` → Egypt; else generic). Make it a parameter if unsure.

### Messages
| Key | English | Arabic |
|---|---|---|
| required | `{field} is required` | `{field} مطلوب` / `هذا الحقل مطلوب` |
| email | `Enter a valid email address` | `أدخل بريدًا إلكترونيًا صحيحًا` |
| passwordShort | `Password must be at least {n} characters` | `كلمة المرور يجب ألا تقل عن {n} أحرف` |
| passwordWeak | `Password must contain letters and numbers` | `كلمة المرور يجب أن تحتوي على حروف وأرقام` |
| confirm | `Passwords do not match` | `كلمتا المرور غير متطابقتين` |
| phone | `Enter a valid phone number` | `أدخل رقم هاتف صحيح` |
| name | `Name must be 2–50 letters` | `الاسم يجب أن يكون من 2 إلى 50 حرفًا` |
| minLength | `Must be at least {n} characters` | `يجب ألا يقل عن {n} أحرف` |
| maxLength | `Must be at most {n} characters` | `يجب ألا يزيد عن {n} حرفًا` |
| number | `Enter a valid number` | `أدخل رقمًا صحيحًا` |
| range | `Must be between {min} and {max}` | `يجب أن يكون بين {min} و {max}` |
| url | `Enter a valid URL` | `أدخل رابطًا صحيحًا` |
| otp | `Enter the {n}-digit code` | `أدخل الرمز المكون من {n} أرقام` |
| select | `Please select {field}` | `يرجى اختيار {field}` |
If the project has `AppStrings`/l10n, add the keys there instead of inline text.

## Form rules (apply to every form/dialog/sheet in the module)
1. `final _formKey = GlobalKey<FormState>();` wrapping all inputs in `Form(key: _formKey, autovalidateMode: AutovalidateMode.onUserInteraction, …)`.
2. `TextField` → `TextFormField` (or the project's wrapper widget, ensuring it forwards `validator`, `keyboardType`, `inputFormatters`, `textInputAction`, `onFieldSubmitted`).
3. Per field type:
   | Field | keyboardType | inputFormatters | validator |
   |---|---|---|---|
   | email | `emailAddress` | `FilteringTextInputFormatter.deny(RegExp(r'\s'))` | email |
   | password | `visiblePassword`, `obscureText` + toggle | — | password (register) / required (login) |
   | phone | `phone` | `FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))`, `LengthLimitingTextInputFormatter(15)` | phone |
   | integer | `number` | `FilteringTextInputFormatter.digitsOnly` | integer(min,max) |
   | decimal/price | `TextInputType.numberWithOptions(decimal: true)` | `FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))` | number(min,max) |
   | name | `name`, `textCapitalization: words` | — | name |
   | multi-line text | `multiline`, `maxLines`, `maxLength` | — | required + maxLength |
   | url | `url` | — | url |
4. Dropdowns → `DropdownButtonFormField` with `validator: (v) => v == null ? msg : null`.
   Date/time pickers → read-only `TextFormField` with `onTap` picker + required validator, or a `FormField<DateTime>`.
   Checkboxes/terms → `FormField<bool>`.
5. Submit:
   ```dart
   Future<void> _submit() async {
     FocusScope.of(context).unfocus();
     if (!_formKey.currentState!.validate()) return;
     setState(() => _saving = true);
     try {
       await provider.save(model);          // model.validate() runs inside the service
       if (!mounted) return;
       showSuccess(); Navigator.pop(context);
     } catch (e) {
       if (!mounted) return;
       showError(e);
     } finally {
       if (mounted) setState(() => _saving = false);
     }
   }
   ```
6. Button `onPressed: _saving ? null : _submit` with a spinner while saving.
7. Never silently coerce bad input (`double.tryParse(x) ?? 0`) — the validator must reject it first; parse with `!` only after validation.
8. Dispose every `TextEditingController` in `dispose()`.
