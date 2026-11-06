# Educore app (Flutter)

The Educore phone app for **parents, teachers and students**, written in Flutter. It replaces the earlier Expo / React Native app and
talks to the same school server, so nothing changes on the server for sign-in, fees, results, attendance, notices and the rest.

Same package name as before (`ng.educore.app`), so it installs over the old app on Android and updates the same Play Store listing.
The version is `2.0.0` (build number `1000`), higher than the old app's.

## What is in it

- **Sign in**: pick the school from the list (or type its address), email / phone / admission number, 30-day sign-in, two-step code, Google sign-in (when the school turns it on), forgotten password with the 6-digit code.
- **Parent**: home, fees (pay a term, chosen milestones or the whole year, optional extra payments, pay on the web and come back to the app, bills / receipts / statements as PDF), results by session and term with report-card PDF, attendance, notices (with reply), messages, meet a teacher, homework, calendar, school bus, boarding, notice settings, help.
- **Teacher**: my day, mark the register, enter scores (with a full-sheet preview), class results, messages, parent meetings, homework, leave, payslips, calendar, search, help.
- **Student**: today, results, notices, homework, online tests (timed), calendar.
- **Everywhere**: session / term picker that every screen follows, light / dark / device appearance, the school's own colour and look, app lock with fingerprint / face, offline copy of screens and an outbox for registers and scores (when the school has weak-network support on), update prompt (the owner's min / latest version rules), account data requests, crash reports to the owner.
- Speed: the screens loaded last time open at once from the phone and refresh behind; the main screens of a role load in the background right after sign-in; the same read asked twice at once is sent once.

## Run it

```bash
flutter pub get
flutter run --dart-define=ROOT_DOMAIN=edu-core.ng          # schools live at <name>.edu-core.ng
# against a local server:  --dart-define=ROOT_DOMAIN=localhost:8000   (schools at <name>.localhost:8000)
flutter test
flutter analyze
```

## Build for Android without Expo (no paid build service)

GitHub builds it for you: push to `main` (or run the **Build** workflow by hand) and download `educore.apk` and `educore.aab` from the run's
Artifacts: `educore.apk` (to install) and `educore.aab` (for Google Play), each its own download, not zipped. To sign with your own upload key, add these repository
secrets: `ANDROID_KEYSTORE_BASE64` (the `.jks` file, base64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
Without them the file is signed with a debug key (fine for testing, not for the store).

### Signed release APK (permanent release keystore)

The production APK is signed with one permanent keystore, `educore-release.jks` (alias `educore`, RSA 4096, valid 10,000 days), kept **outside** this repository.
Never commit it or its passwords (`.gitignore` blocks `android/key.properties`, `*.jks` and `*.keystore`), and never create a new one for a new release:
a different key stops phones that already have the app from updating it. A release build with no keystore **stops with an error**; it is never signed with the debug key.

**Once, on your own computer:** `./tool/create-release-keystore.sh` asks for a password (not shown or logged), creates `~/.educore-keys/educore-release.jks`,
writes `android/key.properties`, and prints the certificate fingerprint. Back the keystore and password up now (password manager plus an offline copy).

**Build on GitHub (recommended).** Add four repository secrets (Settings, Secrets and variables, Actions): `RELEASE_KEYSTORE_BASE64`
(`base64 -w0 ~/.educore-keys/educore-release.jks`), `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS` (`educore`), `RELEASE_KEY_PASSWORD`.
Then Actions, **Release APK**, Run workflow (or push a tag such as `v2.0.1`). It runs `flutter clean`, `flutter pub get`, `flutter build apk --release`,
checks the file with `apksigner verify`, and publishes `app-release.apk` and `app-release.apk.sha256` with the size, package, version and signing fingerprint in the run summary.

**Build on your computer** (with `android/key.properties` in place):

```
flutter clean
flutter pub get
flutter build apk --release
# the file: build/app/outputs/flutter-apk/app-release.apk
"$ANDROID_HOME"/build-tools/<version>/apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
sha256sum build/app/outputs/flutter-apk/app-release.apk
```

Each new release: raise `version:` in `pubspec.yaml` (for example `2.0.1+1001`; the number after `+` must go up every time), then build the same way. The application ID stays `ng.educore.app`.
Upload the APK on the server's *Mobile app* page; the server reads its signing fingerprint and publishes it for app links by itself.

### Signing for Google Play (the key Play expects)

Play only accepts a bundle signed with the **upload key the app was first published with**. For this app Play expects the certificate
with SHA1 `7A:64:2A:10:07:39:96:33:3E:D6:F0:FE:0E:94:99:8A:5C:64:B3:EB`. A build without your keystore is signed with a debug key
(SHA1 `C9:2A:44:A5:...`, which Play refused), so the workflow now makes only the test APK unless the keystore secrets are set, and it stops
if the bundle's key is not the expected one.

1. Get the keystore the old Expo app was uploaded with. If it was managed by EAS: `npx eas-cli credentials -p android` → *production* →
   *Keystore* → *Download existing keystore*. It gives you the `.jks` file, the keystore password, the key alias and the key password.
   (Downloading credentials still works when the free build quota is used up.) Check it: `keytool -list -v -keystore file.jks` must show
   the SHA1 above.
2. Base64 it: `base64 -w0 file.jks` (macOS: `base64 -i file.jks`).
3. In GitHub: Settings → Secrets and variables → Actions → add `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
   `ANDROID_KEY_PASSWORD`. Run the **Build** workflow again; `educore.aab` is then signed with the right key. Until then the run still gives you a bundle, named `educore-debug-key.aab`, which Google Play will refuse.

No old keystore? In Play Console → your app → *Test and release* → *App signing* → **Request upload key reset**. Create a new keystore
(`keytool -genkeypair -v -storetype PKCS12 -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`), upload its
certificate when Play asks, wait for approval, and use that keystore for the four secrets. Keep the keystore and its passwords safe: they cannot be recovered.

**"The bundle is signed with 7A:64... but Google Play expects a different key"** means the keystore in the secrets is a new one, not the one the app was
first uploaded with. Either put the original keystore in the four secrets (the EAS download above), or keep the new one and ask Play to
accept it: *App signing* → **Request upload key reset**, with the certificate from
`keytool -export -rfc -keystore upload.jks -alias <alias> -file upload_cert.pem` (every Build run also publishes it as the artifact `upload_cert.pem`). Play takes a day or two to approve. When it does, add a
repository **variable** (not a secret) `ANDROID_PLAY_UPLOAD_SHA1` with the new key's SHA1 (shown in the build log as "AAB signed with"),
and run **Build** again. Until then Play will refuse `educore.aab` (it is signed correctly with your keystore, Play just does not know that key yet); the APK installs normally.

On your own computer: `flutter build apk --release --dart-define=ROOT_DOMAIN=edu-core.ng` (needs the Android SDK), and
`flutter build appbundle --release ...` for Play. iOS needs a Mac: `flutter build ipa`.

Links in emails (`https://<school>.edu-core.ng/parent/...`) open the app once the owner has added the app's signing fingerprint on the
server's *Mobile app* page. The payment page and Google sign-in return to the app through `educore://payment` and `educore://google-login`.

## Push notifications

The app receives notices through Firebase (FCM). `android/app/google-services.json` (project `educore-62ee3`, package `ng.educore.app`)
is in the repo, and the build applies the Google services plugin only when that file is present.

On the server (educore-web):

1. Firebase console → Project settings → **Service accounts** → **Generate new private key**. Keep the file private.
2. Put the file on the server, outside the web folder, and set in `.env`:
   `FCM_SERVICE_ACCOUNT_FILE=/path/to/educore-62ee3-firebase-adminsdk.json` and `PUSH_DRIVER=expo,fcm`
   (`expo` keeps the older Expo app working while it is still installed; use just `fcm` once it is gone).
   Then `php artisan config:cache` and run `php artisan migrate`.
3. Sign in to the app on a phone and open **Account → Send me a test notice**. The owner's *System check* page also reports whether
   push is on and whether the Firebase key is found.

To replace the Firebase file in a build without committing it, add a repository secret `GOOGLE_SERVICES_JSON` (the file's contents);
the workflow writes it over the one in the repo.

iPhone later: add an iOS app in Firebase, put `GoogleService-Info.plist` in `ios/Runner/`, upload an Apple APNs key in Firebase →
Cloud Messaging, and turn on the Push Notifications capability in Xcode.

## Layout

```
lib/core      api (cache, retry, offline outbox), terms, theme, connectivity
lib/ui        the building blocks: screen, cards, lists, buttons, fields, sheets, loading
lib/features  documents (PDF), pay sheet, app lock, update prompt, term picker, account data, push
lib/screens   login, forgot, parent, teacher, student, inbox, extras ("More"), account, search
lib/shell     tab bar, tab navigation, connectivity banner
```

Not ported from the old app: the Android home-screen widget.
