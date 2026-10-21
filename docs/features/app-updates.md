# In-App OTA Updates & Version Gating

LAJU operates independently of proprietary app stores by implementing a native **One-Click In-App Over-The-Air (OTA) APK Installer** and centralized version policy gating.

---

## 1. Version Policy Resolution

On app startup and resume, the client (`apps/mobile/lib/core/services/app_update_controller.dart`) queries the public endpoint:

```text
GET /admin/app-config/public
```

The response provides:
```json
{
  "latestVersion": "1.0.6",
  "minRequiredVersion": "1.0.4",
  "apkUrl": "/admin/app-config/download-apk",
  "apkSize": "35.2 MB",
  "apkSha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "releaseNotes": "Peningkatan performa video status dan perbaikan notifikasi panggilan.",
  "maintenanceMode": false,
  "maintenanceMessage": ""
}
```

---

## 2. Gating Policies

1. **Maintenance Mode**:
   - If `maintenanceMode == true`, a full-screen non-dismissible maintenance overlay blocks all app interaction until disabled by operators in the Backoffice.
2. **Force Update (Wajib)**:
   - If `currentVersion < minRequiredVersion`, a non-dismissible dialog forces the user to update before accessing chats.
3. **Optional Update (Disarankan)**:
   - If `minRequiredVersion <= currentVersion < latestVersion`, a dismissible dialog prompts the user to upgrade with a "Nanti Saja" (Later) option.

---

## 3. One-Click In-App OTA Installer

Instead of redirecting users to open external web browsers:
1. **Direct Download**: The client downloads the `.apk` directly to app-specific external cache storage (`Android/data/com.laju.laju_mobile/cache`).
2. **Live Progress**: A real-time download progress bar with speed and transferred MB is displayed in-app.
3. **SHA-256 Verification**: Upon completion, the client computes the file hash and verifies it against `apkSha256` to prevent corrupted or tampered installations.
4. **Android FileProvider Execution**: The native package installer is invoked via `FileProvider` with `FLAG_GRANT_READ_URI_PERMISSION`:
   ```kotlin
   val intent = Intent(Intent.ACTION_VIEW).apply {
       setDataAndType(apkUri, "application/vnd.android.package-archive")
       addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
       addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
   }
   context.startActivity(intent)
   ```
5. **Direct OS Install**: Android presents the system "Update" prompt without requiring the user to locate downloaded files manually in the file manager.
