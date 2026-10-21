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

GitHub builds it for you: push to `main` (or run the **Build** workflow by hand) and download `educore-android` from the run's
Artifacts (`app-release.apk` to install, `app-release.aab` for Google Play). To sign with your own upload key, add these repository
secrets: `ANDROID_KEYSTORE_BASE64` (the `.jks` file, base64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
Without them the file is signed with a debug key (fine for testing, not for the store).

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
