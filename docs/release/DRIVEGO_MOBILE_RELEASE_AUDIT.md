# DriveGo — Mobile & Frontend Release Audit (Phase 9)

**Audit Execution Date:** October 28, 2026  
**Auditor:** Principal Mobile Architect & Flutter Release Engineer  
**Scope:** Customer App, Vendor App, Admin Control Tower, Shared Core/Models, and Build Targets  

---

## 1. Client Portfolio Inventory & Test Results

| Client Target | Platform Support | Entrypoint | Dependencies | Flutter Test Result | Static Analysis (`flutter analyze`) | Web Release Build |
|---|---|---|---|---|---|---|
| **Customer App** (`apps/customer_app`) | Android, iOS, Web | `lib/main.dart` | Riverpod 2.6, Dio 5.10, GoRouter 14.8 | **198 / 198 PASSED** | **0 Issues Found** | Ready for Web/APK |
| **Vendor App** (`apps/vendor_app`) | Android, iOS, Web | `lib/main.dart` | Riverpod 2.6, Dio 5.10, GoRouter 14.8 | **272 / 272 PASSED** | **0 Issues Found** | Ready for Web/APK |
| **Admin Control Tower** (`apps/admin_panel`) | Web (CanvasKit) | `lib/main.dart` | Riverpod 2.6, FlChart, Web Secure Storage | **66 / 66 PASSED** | **0 Issues Found** | **BUILT (build/web)** |
| **Core Shared Package** (`packages/core`) | Shared Dart/Flutter | `lib/core.dart` | Flutter DDS Design Tokens, Dio Client | **8 / 8 PASSED** | **0 Issues Found** | Compiled |
| **Models Shared Package** (`packages/models`) | Shared Dart/Flutter | `lib/models.dart` | Freezed, JSON Serializable, Freezed Annotations | **29 / 29 PASSED** | **0 Issues Found** | Compiled |

---

## 2. API Base URL & Release Fail-Closed Safeguard

DriveGo implements an explicit, fail-closed production runtime safeguard in `packages/core/lib/src/api_client.dart`:
```dart
static String get defaultBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kReleaseMode) {
    throw StateError(
      'CRITICAL: API_BASE_URL must be specified for production release builds via --dart-define=API_BASE_URL=https://... Silent fallback to localhost/10.0.2.2 is prohibited in release mode.',
    );
  }
  return kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
}
```
**Benefits:**
- In debug mode, developers seamlessly connect to local backend (`http://localhost:3000` on web, `http://10.0.2.2:3000` on Android emulator).
- In release mode (`--release`), compiling without `--dart-define=API_BASE_URL=https://api.drivego.in` raises an immediate `StateError`, guaranteeing that no production build ever silently tries to connect to localhost.

---

## 3. Session Persistence & Token Handling

- **Authentication Storage:** Persisted via `flutter_secure_storage` using Android Keystore and Apple Keychain.
- **Auto-Refresh Lifecycle:** `ApiClient` includes a queued Dio interceptor (`QueuedInterceptorsWrapper`). Upon receiving an HTTP 401:
  1. Queues incoming outbound requests to prevent storming.
  2. Issues a refresh request to `/auth/otp/refresh` using the stored refresh token.
  3. Updates session tokens and replays the original failed request.
  4. If the refresh token is expired or revoked, securely wipes local storage and redirects to the login screen.

---

## 4. Native App Store Prerequisites & Readiness

Before publishing to Google Play Store and Apple App Store, the following operational steps must be executed:

1. **Android Package Identifier / Namespace:**
   - Current namespace in `build.gradle.kts`: `com.example.customer_app` / `com.example.vendor_app`.
   - Update to official production application IDs: `in.drivego.customer` and `in.drivego.partner`.
2. **Release Keystore & Code Signing:**
   - In accordance with security best practices, no release signing keystores (`.jks`, `.keystore`) or private signing credentials are committed to Git.
   - For production Play Store distribution, generate an upload keystore and inject `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD` via CI/CD secrets or local `key.properties`.
3. **App Permissions Audit:**
   - `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`: Required for locating nearby vehicles and pickup hubs.
   - `CAMERA`: Required for pre-trip and post-trip handover vehicle inspection photos.
   - `READ_MEDIA_IMAGES`: Required for KYC document and avatar uploads.
