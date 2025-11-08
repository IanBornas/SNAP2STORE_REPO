# flutter_app
A production build & deployment quick guide has been added below.

## Production Build (Android)

1. Choose a public URL for the AI backend (after deploying `backend/` container). Example: `https://ai-backend-yourname.onrender.com`.
2. Build release APK (per-ABI smaller files recommended):
	```powershell
	flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://ai-backend-yourname.onrender.com
	```
	Output paths:
	- `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`
	- `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk`
	- `build\app\outputs\flutter-apk\app-x86_64-release.apk`

3. (Play Store) Build App Bundle:
	```powershell
	flutter build appbundle --release --dart-define=API_BASE_URL=https://ai-backend-yourname.onrender.com
	```
	Output: `build\app\outputs\bundle\release\app-release.aab`

## Backend Deployment (Render)

The `backend/` directory contains:
- `Dockerfile` (production: gunicorn, healthcheck on `/warmup`)
- `render.yaml` (example Render blueprint)

Deploy steps:
1. Commit & push changes.
2. In Render.com dashboard: New + Blueprint, provide repo & select `backend/render.yaml`.
3. Set environment variables (API keys):
	- `GOOGLE_VISION_API_KEY`
	- `GOOGLE_MAPS_API_KEY`
	- (Optional) `GOOGLE_APPLICATION_CREDENTIALS` path after mounting service account file.
4. After deploy, visit `/warmup` to verify models load.

## Updating App Icon
Icon source: `assets/images/app_icon.png`. Regenerate if changed:
```powershell
flutter pub run flutter_launcher_icons:main
```

## Local Dev Convenience
- VS Code F5 launches backend (preLaunchTask) then Flutter.
- Script: `scripts/start-dev.ps1` starts backend then runs `flutter run`.

## Supabase Notes
Supabase URL & anon key currently hard-coded in `lib/main.dart`. For production security:
1. Move them to dart-define values:
	```powershell
	flutter build apk --release \
	  --dart-define=API_BASE_URL=https://ai-backend-yourname.onrender.com \
	  --dart-define=SUPABASE_URL=https://YOURPROJECT.supabase.co \
	  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
	```
2. In `main.dart`, replace literals with:
	```dart
	const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
	const supabaseAnon = String.fromEnvironment('SUPABASE_ANON_KEY');
	```

## Healthcheck & Readiness
- Container healthcheck uses `/warmup` for deeper readiness (models/API clients).
- Flutter app performs non-blocking warmup via `BackendService.ping()`.

## Next Hardening Ideas
- Add retries + exponential backoff for backend calls.
- Use secure storage for tokens (on mobile) if auth added.
- Configure CI to build & upload artifacts automatically.


A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
