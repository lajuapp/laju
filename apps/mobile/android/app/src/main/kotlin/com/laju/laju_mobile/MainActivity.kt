package com.laju.laju_mobile

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.AudioDeviceInfo
import android.media.ExifInterface
import java.io.ByteArrayOutputStream
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.content.Context
import android.os.PowerManager
import android.widget.FrameLayout
import android.widget.VideoView
import android.view.View
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.URL
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import android.location.Location
import android.location.LocationManager
import android.location.LocationListener
import android.location.Geocoder
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    private val CAMERA_CHANNEL = "com.laju/camera"
    private val VOICE_CHANNEL = "com.laju/voice_note"
    private val BIOMETRIC_CHANNEL = "com.laju/biometric"
    private val SOUND_CHANNEL = "com.laju/sound"
    private val CALL_AUDIO_CHANNEL = "com.laju/call_audio"
    private val NOTIFICATION_CHANNEL = "com.laju/system_notifications"
    private val LOCATION_CHANNEL = "com.laju/location"
    private val DEVICE_CHANNEL = "com.laju/device"
    private val CHANNEL_ID_CALLS = "laju_calls"
    private val CHANNEL_ID_MESSAGES = "laju_messages"

    private var currentAudioTrack: AudioTrack? = null
    private var currentSystemRingtone: Ringtone? = null

    private var callAudioRecord: AudioRecord? = null
    private var callAudioTrack: AudioTrack? = null
    private val audioTrackLock = Any()
    private val audioPlaybackQueue = java.util.concurrent.LinkedBlockingQueue<ByteArray>(60)
    private var pendingCallAudioArgs: Map<String, Any>? = null
    private var callAudioSocket: DatagramSocket? = null
    @Volatile private var isCallAudioActive = false
    @Volatile private var isCallAudioMuted = false
    @Volatile private var isCallAudioSpeaker = false
    @Volatile private var callRemoteIp: String = ""
    @Volatile private var callRemotePort: Int = 50005
    private var launchPayload: Map<String, Any?>? = null

    private var aecEffect: AcousticEchoCanceler? = null
    private var nsEffect: NoiseSuppressor? = null
    private var ringbackToneTrack: AudioTrack? = null
    @Volatile private var isPlayingCallTone = false

    private val CAMERA_REQUEST_CODE = 1001
    private val GALLERY_REQUEST_CODE = 1002
    private val RECORD_AUDIO_REQUEST_CODE = 1003
    private val DOCUMENT_REQUEST_CODE = 1004
    private val AUDIO_REQUEST_CODE = 1005
    private val CONTACT_REQUEST_CODE = 1006
    private val CAMERA_PERMISSION_REQUEST_CODE = 1007
    private val LOCATION_PERMISSION_REQUEST_CODE = 1008
    private val STORAGE_PERMISSION_REQUEST_CODE = 1009
    private val VIDEO_CAMERA_REQUEST_CODE = 1010
    private val VIDEO_GALLERY_REQUEST_CODE = 1011

    private var currentCameraCapturePath: String? = null
    private var pendingCameraResult: MethodChannel.Result? = null
    private var pendingMediaResult: MethodChannel.Result? = null
    private var pendingAudioPermissionResult: MethodChannel.Result? = null
    private var pendingCameraPermissionResult: MethodChannel.Result? = null
    private var pendingLocationPermissionResult: MethodChannel.Result? = null
    private var pendingStoragePermissionResult: MethodChannel.Result? = null

    private var mediaRecorder: MediaRecorder? = null
    private var currentRecordingFile: File? = null
    private var recordingStartTime: Long = 0L

    private var mediaPlayer: MediaPlayer? = null
    private var currentPlayingPath: String? = null
    private var voiceMethodChannel: MethodChannel? = null
    private var notificationMethodChannel: MethodChannel? = null

    companion object {
        var instance: MainActivity? = null
        var isAppInForeground: Boolean = false
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        instance = this
        super.onCreate(savedInstanceState)
        createNotificationChannels()
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        isAppInForeground = true
    }

    override fun onPause() {
        super.onPause()
        isAppInForeground = false
    }

    override fun onDestroy() {
        isAppInForeground = false
        if (instance == this) instance = null
        stopCallTone()
        stopRealtimeCallAudio()
        try {
            mediaRecorder?.stop()
        } catch (_: Exception) {}
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {}
        mediaRecorder = null

        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {}
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null

        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    fun dispatchCallAction(callId: String, action: String, isVideo: Boolean = false, callerName: String = "Panggilan") {
        try {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(9999)
            nm.cancel(8888)
        } catch (_: Exception) {}
        stopCurrentRingtone()
        stopCallTone()

        if (notificationMethodChannel != null) {
            runOnUiThread {
                notificationMethodChannel?.invokeMethod("onCallAction", mapOf(
                    "callId" to callId,
                    "action" to action,
                    "isVideo" to isVideo,
                    "callerName" to callerName
                ))
            }
        } else {
            launchPayload = mapOf(
                "type" to "call",
                "id" to callId,
                "action" to action,
                "isVideo" to isVideo,
                "callerName" to callerName
            )
        }
    }

    fun dispatchPushMessage(conversationId: String, senderName: String, preview: String) {
        if (notificationMethodChannel != null) {
            runOnUiThread {
                notificationMethodChannel?.invokeMethod("onNewMessage", mapOf(
                    "conversationId" to conversationId,
                    "senderName" to senderName,
                    "preview" to preview
                ))
            }
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val type = intent.getStringExtra("laju_type")
        val id = intent.getStringExtra("laju_id")
        val isVideo = intent.getBooleanExtra("laju_is_video", false)
        val action = intent.getStringExtra("laju_action")
        val callerName = intent.getStringExtra("laju_caller_name") ?: "Panggilan"

        if (type == "call" && id != null) {
            if (action == "answer" || action == "decline") {
                dispatchCallAction(id, action, isVideo, callerName)
                return
            }
            launchPayload = mapOf("type" to type, "id" to id, "isVideo" to isVideo, "action" to action, "callerName" to callerName)
        } else if (type != null && id != null) {
            launchPayload = mapOf("type" to type, "id" to id, "isVideo" to isVideo, "action" to action)
        }

        // Handle Deep Link / App Link URIs (laju:// and https://laju.chat/u/...)
        val uri = intent.data
        if (uri != null) {
            val scheme = uri.scheme
            val host = uri.host
            val path = uri.path ?: ""
            var contactUsername: String? = null
            var contactId: String? = null

            if (scheme == "laju") {
                if (host == "contact" || path.startsWith("/contact")) {
                    contactUsername = uri.getQueryParameter("u") ?: uri.getQueryParameter("username")
                    contactId = uri.getQueryParameter("id") ?: uri.getQueryParameter("userId")
                } else if (host == "u" || path.startsWith("/u/")) {
                    contactUsername = if (host == "u") path.removePrefix("/") else path.removePrefix("/u/")
                }
            } else if (scheme == "https" || scheme == "http") {
                if (path.startsWith("/u/")) {
                    contactUsername = path.removePrefix("/u/").split("?").first()
                    contactId = uri.getQueryParameter("id")
                } else if (path.startsWith("/contact")) {
                    contactUsername = uri.getQueryParameter("u")
                    contactId = uri.getQueryParameter("id")
                }
            }

            if (!contactUsername.isNullOrEmpty()) {
                val cleanUser = Uri.decode(contactUsername).trim().removePrefix("@")
                launchPayload = mapOf(
                    "type" to "contact",
                    "username" to cleanUser,
                    "id" to (contactId ?: "")
                )
            }
        }
    }

    private fun saveToGallery(imageBytes: ByteArray, fileName: String): Boolean {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val now = System.currentTimeMillis()
                val contentValues = android.content.ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + java.io.File.separator + "LAJU")
                    put(MediaStore.Images.Media.DATE_ADDED, now / 1000)
                    put(MediaStore.Images.Media.DATE_TAKEN, now)
                }
                val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                    ?: contentResolver.insert(MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), contentValues)

                if (uri != null) {
                    contentResolver.openOutputStream(uri)?.use { stream ->
                        stream.write(imageBytes)
                        stream.flush()
                    }
                    return true
                }
            }

            // Legacy Android <= 9 or fallback
            val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val lajuDir = java.io.File(picturesDir, "LAJU").apply { if (!exists()) mkdirs() }
            val file = java.io.File(lajuDir, fileName)
            file.writeBytes(imageBytes)
            android.media.MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(file.absolutePath),
                arrayOf("image/png"),
                null
            )
            return true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "saveToGallery error: ${e.message}", e)
            try {
                val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                val lajuDir = java.io.File(picturesDir, "LAJU").apply { if (!exists()) mkdirs() }
                val file = java.io.File(lajuDir, fileName)
                file.writeBytes(imageBytes)
                android.media.MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(file.absolutePath),
                    arrayOf("image/png"),
                    null
                )
                return true
            } catch (fallbackEx: Exception) {
                android.util.Log.e("MainActivity", "saveToGallery fallback failed: ${fallbackEx.message}", fallbackEx)
                return false
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            val callAttrs = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .build()

            val callChannel = NotificationChannel(
                CHANNEL_ID_CALLS,
                "Panggilan Masuk LAJU",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi panggilan suara dan video masuk"
                setSound(ringtoneUri, callAttrs)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 800, 400, 800, 400, 800)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(callChannel)

            val msgUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val msgAttrs = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                .build()

            val msgChannel = NotificationChannel(
                CHANNEL_ID_MESSAGES,
                "Pesan Masuk LAJU",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi pesan baru terenkripsi"
                setSound(msgUri, msgAttrs)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 150, 250)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(msgChannel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native Video Player PlatformView for Status and Media Playback
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.laju/native_video_view",
            NativeVideoPlayerFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        // Camera & Gallery MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasCameraPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestCameraPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingCameraPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.CAMERA),
                            CAMERA_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "openSystemCamera" -> {
                    pendingCameraResult = result
                    val hasPerm = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                    if (hasPerm) {
                        launchSystemCamera()
                    } else {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.CAMERA),
                            CAMERA_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "openGallery" -> {
                    pendingCameraResult = result
                    try {
                        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                        intent.type = "image/*"
                        startActivityForResult(intent, GALLERY_REQUEST_CODE)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Intent.ACTION_GET_CONTENT)
                            intent.type = "image/*"
                            startActivityForResult(intent, GALLERY_REQUEST_CODE)
                        } catch (e2: Exception) {
                            result.error("GALLERY_ERROR", e2.message, null)
                            pendingCameraResult = null
                        }
                    }
                }
                "openVideoCamera" -> {
                    pendingCameraResult = result
                    val hasPerm = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                    val hasAudio = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    if (hasPerm && hasAudio) {
                        launchSystemVideoCamera()
                    } else {
                        val perms = mutableListOf<String>()
                        if (!hasPerm) perms.add(Manifest.permission.CAMERA)
                        if (!hasAudio) perms.add(Manifest.permission.RECORD_AUDIO)
                        ActivityCompat.requestPermissions(
                            this,
                            perms.toTypedArray(),
                            CAMERA_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "openVideoGallery" -> {
                    pendingCameraResult = result
                    try {
                        val intent = Intent(Intent.ACTION_PICK, MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
                        intent.type = "video/*"
                        startActivityForResult(intent, VIDEO_GALLERY_REQUEST_CODE)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Intent.ACTION_GET_CONTENT)
                            intent.type = "video/*"
                            startActivityForResult(intent, VIDEO_GALLERY_REQUEST_CODE)
                        } catch (e2: Exception) {
                            result.error("VIDEO_GALLERY_ERROR", e2.message, null)
                            pendingCameraResult = null
                        }
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "savePermanentAvatar" -> {
                    val srcPath = call.argument<String>("path")
                    if (srcPath != null) {
                        try {
                            val srcFile = File(srcPath)
                            if (srcFile.exists()) {
                                val optimized = compressAndDownsampleImage(srcFile.absolutePath, maxDimension = 512, quality = 85)
                                val optFile = File(optimized)
                                val destFile = File(filesDir, "user_avatar_${System.currentTimeMillis()}.jpg")
                                filesDir.listFiles()?.forEach { f ->
                                    if (f.name.startsWith("user_avatar_")) {
                                        f.delete()
                                    }
                                }
                                optFile.copyTo(destFile, overwrite = true)
                                result.success(destFile.absolutePath)
                            } else {
                                result.error("FILE_NOT_FOUND", "Source file does not exist", null)
                            }
                        } catch (e: Exception) {
                            result.error("SAVE_AVATAR_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Path argument missing", null)
                    }
                }
                "compressImage" -> {
                    val path = call.argument<String>("path")
                    val maxDim = call.argument<Int>("maxDimension") ?: 1280
                    val quality = call.argument<Int>("quality") ?: 82
                    if (path != null) {
                        val compressed = compressAndDownsampleImage(path, maxDimension = maxDim, quality = quality)
                        result.success(compressed)
                    } else {
                        result.error("INVALID_ARGS", "Path argument missing", null)
                    }
                }
                "openDocument" -> {
                    pendingMediaResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        startActivityForResult(intent, DOCUMENT_REQUEST_CODE)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                                type = "*/*"
                            }
                            startActivityForResult(intent, DOCUMENT_REQUEST_CODE)
                        } catch (e2: Exception) {
                            result.error("DOCUMENT_ERROR", e2.message, null)
                            pendingMediaResult = null
                        }
                    }
                }
                "openAudio" -> {
                    pendingMediaResult = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "audio/*"
                        }
                        startActivityForResult(intent, AUDIO_REQUEST_CODE)
                    } catch (e: Exception) {
                        result.error("AUDIO_PICK_ERROR", e.message, null)
                        pendingMediaResult = null
                    }
                }
                "openContact" -> {
                    pendingMediaResult = result
                    try {
                        val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                        startActivityForResult(intent, CONTACT_REQUEST_CODE)
                    } catch (e: Exception) {
                        result.error("CONTACT_PICK_ERROR", e.message, null)
                        pendingMediaResult = null
                    }
                }
                "shareContent" -> {
                    val text = call.argument<String>("text")
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val filePath = call.argument<String>("filePath")
                    val title = call.argument<String>("title") ?: "Bagikan Kode QR LAJU"

                    try {
                        var targetFile: File? = null
                        val storageDir = externalCacheDir ?: cacheDir
                        val sharedDir = File(storageDir, "shared").apply { if (!exists()) mkdirs() }
                        if (imageBytes != null && imageBytes.isNotEmpty()) {
                            val file = File(sharedDir, "laju_qr_${System.currentTimeMillis()}.png")
                            file.writeBytes(imageBytes)
                            file.setReadable(true, false)
                            targetFile = file
                        } else if (filePath != null && File(filePath).exists()) {
                            targetFile = File(filePath)
                        }

                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            if (targetFile != null && targetFile.exists()) {
                                val photoUri = FileProvider.getUriForFile(
                                    this@MainActivity,
                                    "${applicationContext.packageName}.fileprovider",
                                    targetFile
                                )
                                type = "image/png"
                                putExtra(Intent.EXTRA_STREAM, photoUri)
                                if (text != null) {
                                    putExtra(Intent.EXTRA_TEXT, text)
                                }
                                val clipItem = ClipData.Item(photoUri)
                                clipData = ClipData(
                                    ClipDescription("LAJU QR Code", arrayOf("image/png")),
                                    clipItem
                                )
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

                                val resInfoList = packageManager.queryIntentActivities(this, PackageManager.MATCH_DEFAULT_ONLY)
                                for (resolveInfo in resInfoList) {
                                    val pkg = resolveInfo.activityInfo.packageName
                                    try {
                                        grantUriPermission(pkg, photoUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    } catch (_: Exception) {}
                                }

                                val wellKnown = listOf("com.whatsapp", "com.whatsapp.w4b", "org.telegram.messenger")
                                for (pkg in wellKnown) {
                                    try {
                                        grantUriPermission(pkg, photoUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    } catch (_: Exception) {}
                                }
                            } else {
                                type = "text/plain"
                                if (text != null) {
                                    putExtra(Intent.EXTRA_TEXT, text)
                                }
                            }
                        }
                        val chooser = Intent.createChooser(sendIntent, title).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            if (targetFile != null && targetFile.exists()) {
                                val photoUri = FileProvider.getUriForFile(
                                    this@MainActivity,
                                    "${applicationContext.packageName}.fileprovider",
                                    targetFile
                                )
                                val clipItem = ClipData.Item(photoUri)
                                clipData = ClipData(
                                    ClipDescription("LAJU QR Code", arrayOf("image/png")),
                                    clipItem
                                )
                            }
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "shareContent error: ${e.message}", e)
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                "saveImageToGallery" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val fileName = call.argument<String>("fileName") ?: "laju_qr_${System.currentTimeMillis()}.png"
                    if (imageBytes == null || imageBytes.isEmpty()) {
                        result.error("EMPTY_BYTES", "Image bytes cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val saved = saveToGallery(imageBytes, fileName)
                        result.success(saved)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "saveImageToGallery error: ${e.message}", e)
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }
                "hasStoragePermission" -> {
                    val hasPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        true
                    } else {
                        ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    }
                    result.success(hasPerm)
                }
                "requestStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        result.success(true)
                    } else {
                        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success(true)
                        } else {
                            pendingStoragePermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE, Manifest.permission.READ_EXTERNAL_STORAGE),
                                STORAGE_PERMISSION_REQUEST_CODE
                            )
                        }
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "openAppSettings error: ${e.message}", e)
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Voice Note & Audio Playback MethodChannel
        val voiceChan = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
        voiceMethodChannel = voiceChan
        voiceChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasRecordPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestRecordPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingAudioPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            RECORD_AUDIO_REQUEST_CODE
                        )
                    }
                }
                "startRecording" -> {
                    val hasPerm = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    if (!hasPerm) {
                        result.error("PERMISSION_DENIED", "Microphone permission is not granted", null)
                        return@setMethodCallHandler
                    }

                    try {
                        // Stop any existing recorder
                        try {
                            mediaRecorder?.stop()
                            mediaRecorder?.release()
                        } catch (_: Exception) {}
                        mediaRecorder = null

                        // Ensure voice_notes cache directory exists
                        val voiceDir = File(cacheDir, "voice_notes")
                        if (!voiceDir.exists()) {
                            voiceDir.mkdirs()
                        }

                        val file = File(voiceDir, "voice_note_${System.currentTimeMillis()}.m4a")
                        currentRecordingFile = file
                        recordingStartTime = System.currentTimeMillis()

                        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            MediaRecorder(this)
                        } else {
                            @Suppress("DEPRECATION")
                            MediaRecorder()
                        }

                        recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                        recorder.setAudioEncodingBitRate(128000)
                        recorder.setAudioSamplingRate(44100)
                        recorder.setOutputFile(file.absolutePath)
                        recorder.prepare()
                        recorder.start()

                        mediaRecorder = recorder
                        result.success(file.absolutePath)
                    } catch (e: Exception) {
                        mediaRecorder = null
                        currentRecordingFile = null
                        result.error("START_RECORD_ERROR", e.message, null)
                    }
                }
                "stopRecording" -> {
                    val recorder = mediaRecorder
                    val file = currentRecordingFile
                    if (recorder != null && file != null) {
                        val durationMs = System.currentTimeMillis() - recordingStartTime
                        try {
                            recorder.stop()
                        } catch (e: Exception) {
                            // If user stopped too quickly
                        }
                        recorder.release()
                        mediaRecorder = null
                        currentRecordingFile = null

                        if (file.exists() && file.length() > 0) {
                            val res = HashMap<String, Any>()
                            res["path"] = file.absolutePath
                            res["durationMs"] = durationMs
                            res["fileSize"] = file.length()
                            result.success(res)
                        } else {
                            result.error("RECORD_EMPTY", "Recorded audio is empty or not created", null)
                        }
                    } else {
                        result.error("NOT_RECORDING", "No active recording in progress", null)
                    }
                }
                "cancelRecording" -> {
                    try {
                        try {
                            mediaRecorder?.stop()
                        } catch (_: Exception) {}
                        mediaRecorder?.release()
                        mediaRecorder = null
                        currentRecordingFile?.delete()
                        currentRecordingFile = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "playAudio" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "Audio file does not exist: $filePath", null)
                        return@setMethodCallHandler
                    }

                    try {
                        // If same file is paused, simply resume
                        if (mediaPlayer != null && currentPlayingPath == filePath) {
                            if (!mediaPlayer!!.isPlaying) {
                                mediaPlayer!!.start()
                                val data = HashMap<String, Any>()
                                data["durationMs"] = mediaPlayer!!.duration
                                data["positionMs"] = mediaPlayer!!.currentPosition
                                data["isPlaying"] = true
                                result.success(data)
                                return@setMethodCallHandler
                            }
                        }

                        mediaPlayer?.release()
                        mediaPlayer = MediaPlayer().apply {
                            setDataSource(filePath)
                            prepare()
                            start()
                            setOnCompletionListener {
                                Handler(Looper.getMainLooper()).post {
                                    voiceMethodChannel?.invokeMethod("onPlaybackCompleted", mapOf("filePath" to filePath))
                                }
                            }
                        }
                        currentPlayingPath = filePath

                        val data = HashMap<String, Any>()
                        data["durationMs"] = mediaPlayer!!.duration
                        data["positionMs"] = 0
                        data["isPlaying"] = true
                        result.success(data)
                    } catch (e: Exception) {
                        mediaPlayer?.release()
                        mediaPlayer = null
                        currentPlayingPath = null
                        result.error("PLAY_ERROR", e.message, null)
                    }
                }
                "pauseAudio" -> {
                    try {
                        if (mediaPlayer != null && mediaPlayer!!.isPlaying) {
                            mediaPlayer!!.pause()
                            val data = HashMap<String, Any>()
                            data["positionMs"] = mediaPlayer!!.currentPosition
                            data["isPlaying"] = false
                            result.success(data)
                        } else {
                            val data = HashMap<String, Any>()
                            data["positionMs"] = mediaPlayer?.currentPosition ?: 0
                            data["isPlaying"] = false
                            result.success(data)
                        }
                    } catch (e: Exception) {
                        result.error("PAUSE_ERROR", e.message, null)
                    }
                }
                "stopAudio" -> {
                    try {
                        mediaPlayer?.stop()
                        mediaPlayer?.release()
                        mediaPlayer = null
                        currentPlayingPath = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                "seekAudio" -> {
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    try {
                        mediaPlayer?.seekTo(positionMs)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SEEK_ERROR", e.message, null)
                    }
                }
                "getPlaybackStatus" -> {
                    if (mediaPlayer != null) {
                        val isPlaying = try { mediaPlayer!!.isPlaying } catch (_: Exception) { false }
                        val pos = try { mediaPlayer!!.currentPosition } catch (_: Exception) { 0 }
                        val dur = try { mediaPlayer!!.duration } catch (_: Exception) { 0 }
                        val data = HashMap<String, Any?>()
                        data["isPlaying"] = isPlaying
                        data["positionMs"] = pos
                        data["durationMs"] = dur
                        data["filePath"] = currentPlayingPath
                        result.success(data)
                    } else {
                        val data = HashMap<String, Any?>()
                        data["isPlaying"] = false
                        data["positionMs"] = 0
                        data["durationMs"] = 0
                        data["filePath"] = null
                        result.success(data)
                    }
                }
                "getAudioDuration" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.success(0)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.success(0)
                        return@setMethodCallHandler
                    }
                    try {
                        val mmr = android.media.MediaMetadataRetriever()
                        mmr.setDataSource(filePath)
                        val durationStr = mmr.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)
                        val durationMs = durationStr?.toIntOrNull() ?: 0
                        mmr.release()
                        result.success(durationMs)
                    } catch (_: Exception) {
                        result.success(0)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Hardware Biometrics MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BIOMETRIC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canAuthenticate" -> {
                    try {
                        val biometricManager = BiometricManager.from(this)
                        val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL
                        val canAuth = biometricManager.canAuthenticate(authenticators)
                        val pm = packageManager
                        val hasFingerprint = pm.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
                        val hasFace = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            pm.hasSystemFeature(PackageManager.FEATURE_FACE)
                        } else false
                        val hasIris = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            pm.hasSystemFeature(PackageManager.FEATURE_IRIS)
                        } else false

                        val bioTypes = ArrayList<String>()
                        if (hasFingerprint) bioTypes.add("Fingerprint")
                        if (hasFace) bioTypes.add("Face")
                        if (hasIris) bioTypes.add("Iris")

                        val label = when {
                            hasFingerprint && hasFace -> "Fingerprint & Face Recognition"
                            hasFingerprint -> "Fingerprint Sensor"
                            hasFace -> "Face Recognition"
                            hasIris -> "Iris Scanner"
                            else -> "Kunci Layar / Biometrik"
                        }

                        val res = HashMap<String, Any>()
                        res["canAuthenticate"] = (canAuth == BiometricManager.BIOMETRIC_SUCCESS)
                        res["status"] = when (canAuth) {
                            BiometricManager.BIOMETRIC_SUCCESS -> "SUCCESS"
                            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "NO_HARDWARE"
                            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "HW_UNAVAILABLE"
                            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "NONE_ENROLLED"
                            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> "SECURITY_UPDATE_REQUIRED"
                            else -> "UNKNOWN"
                        }
                        res["hasFingerprint"] = hasFingerprint
                        res["hasFace"] = hasFace
                        res["hasIris"] = hasIris
                        res["biometricTypes"] = bioTypes
                        res["biometricLabel"] = label
                        res["deviceModel"] = "${Build.MANUFACTURER.replaceFirstChar { if (it.isLowerCase()) it.titlecase(java.util.Locale.getDefault()) else it.toString() }} ${Build.MODEL}".trim()
                        result.success(res)
                    } catch (e: Exception) {
                        result.error("BIOMETRIC_CHECK_ERROR", e.message, null)
                    }
                }
                "authenticate" -> {
                    val title = call.argument<String>("title") ?: "Autentikasi Biometrik"
                    val subtitle = call.argument<String>("subtitle")
                    val description = call.argument<String>("description")
                    val allowDeviceCredential = call.argument<Boolean>("allowDeviceCredential") ?: true
                    val negativeButtonText = call.argument<String>("negativeButtonText") ?: "Batal"

                    try {
                        val executor = ContextCompat.getMainExecutor(this)
                        val promptInfoBuilder = BiometricPrompt.PromptInfo.Builder()
                            .setTitle(title)

                        if (!subtitle.isNullOrEmpty()) {
                            promptInfoBuilder.setSubtitle(subtitle)
                        }
                        if (!description.isNullOrEmpty()) {
                            promptInfoBuilder.setDescription(description)
                        }

                        if (allowDeviceCredential) {
                            // Allow biometric with device credential fallback (PIN, Pattern, Password)
                            promptInfoBuilder.setAllowedAuthenticators(
                                BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL
                            )
                        } else {
                            // Pure biometric authentication with custom negative cancel button
                            promptInfoBuilder.setAllowedAuthenticators(
                                BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.BIOMETRIC_WEAK
                            )
                            promptInfoBuilder.setNegativeButtonText(negativeButtonText)
                        }

                        val promptInfo = promptInfoBuilder.build()

                        var hasResponded = false
                        val biometricPrompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                            override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                                super.onAuthenticationSucceeded(authResult)
                                if (!hasResponded) {
                                    hasResponded = true
                                    val res = HashMap<String, Any>()
                                    res["success"] = true
                                    result.success(res)
                                }
                            }

                            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                super.onAuthenticationError(errorCode, errString)
                                if (!hasResponded) {
                                    hasResponded = true
                                    val res = HashMap<String, Any>()
                                    res["success"] = false
                                    res["errorCode"] = errorCode
                                    res["errorMessage"] = errString.toString()
                                    result.success(res)
                                }
                            }

                            override fun onAuthenticationFailed() {
                                super.onAuthenticationFailed()
                                // Fingerprint didn't match, Android dialog lets user retry.
                            }
                        })

                        biometricPrompt.authenticate(promptInfo)
                    } catch (e: Exception) {
                        result.error("BIOMETRIC_AUTH_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Sound, Ringtone & Vibration MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playRingtone" -> {
                    val name = call.argument<String>("name") ?: "Default"
                    playSynthesizedRingtone(name)
                    result.success(true)
                }
                "triggerVibrate" -> {
                    val mode = call.argument<String>("mode") ?: "Default"
                    triggerVibrate(mode)
                    result.success(true)
                }
                "stopRingtone" -> {
                    stopCurrentRingtone()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Real-time Two-way Call Audio MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalIp" -> {
                    val ip = getActiveLocalIpAddress()
                    result.success(ip)
                }
                "startCallAudio" -> {
                    val remoteIp = call.argument<String>("remoteIp") ?: ""
                    val remotePort = call.argument<Int>("remotePort") ?: 50005
                    val localPort = call.argument<Int>("localPort") ?: 50005
                    val isSpeaker = call.argument<Boolean>("isSpeaker") ?: false
                    val isVideo = call.argument<Boolean>("isVideo") ?: false
                    val baseUrl = call.argument<String>("baseUrl") ?: ""
                    val callId = call.argument<String>("callId") ?: ""
                    val token = call.argument<String>("token") ?: ""

                    startRealtimeCallAudio(remoteIp, remotePort, localPort, isSpeaker || isVideo, baseUrl, callId, token)
                    result.success(true)
                }
                "updatePeerAddress" -> {
                    val ip = call.argument<String>("ip") ?: ""
                    val port = call.argument<Int>("port") ?: 50005
                    if (ip.isNotEmpty()) {
                        callRemoteIp = ip
                        callRemotePort = port
                    }
                    result.success(true)
                }
                "playAudioChunk" -> {
                    val chunkBase64 = call.argument<String>("chunk") ?: ""
                    if (chunkBase64.isNotEmpty()) {
                        try {
                            val bytes = android.util.Base64.decode(chunkBase64, android.util.Base64.NO_WRAP)
                            if (bytes.isNotEmpty() && audioPlaybackQueue.size < 60) {
                                audioPlaybackQueue.offer(bytes)
                            }
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "stopCallAudio" -> {
                    stopRealtimeCallAudio()
                    result.success(true)
                }
                "setMute" -> {
                    val muted = call.argument<Boolean>("muted") ?: false
                    isCallAudioMuted = muted
                    result.success(true)
                }
                "setSpeaker" -> {
                    val speaker = call.argument<Boolean>("speaker") ?: false
                    setCallSpeakerphone(speaker)
                    result.success(true)
                }
                "hasRecordPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestRecordPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingAudioPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            RECORD_AUDIO_REQUEST_CODE
                        )
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "convertYuvToJpeg" -> {
                    try {
                        val y = call.argument<ByteArray>("y")
                        val u = call.argument<ByteArray>("u")
                        val v = call.argument<ByteArray>("v")
                        val width = call.argument<Int>("width") ?: 0
                        val height = call.argument<Int>("height") ?: 0
                        val yRowStride = call.argument<Int>("yRowStride") ?: width
                        val uvRowStride = call.argument<Int>("uvRowStride") ?: width
                        val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1
                        val quality = call.argument<Int>("quality") ?: 60
                        val isFront = call.argument<Boolean>("isFront") ?: true

                        if (y == null || u == null || v == null || width == 0 || height == 0) {
                            result.error("INVALID_ARGS", "Missing YUV plane data", null)
                            return@setMethodCallHandler
                        }

                        // Convert YUV420 to NV21 format (Y plane followed by interleaved V, U)
                        val nv21 = ByteArray(width * height * 3 / 2)
                        var pos = 0

                        // Copy Y plane (handling row stride)
                        for (row in 0 until height) {
                            val yOffset = row * yRowStride
                            System.arraycopy(y, yOffset, nv21, pos, width)
                            pos += width
                        }

                        // Interleave V and U planes (NV21 format expects V then U)
                        val uvHeight = height / 2
                        val uvWidth = width / 2
                        for (row in 0 until uvHeight) {
                            val uRowOffset = row * uvRowStride
                            val vRowOffset = row * uvRowStride
                            for (col in 0 until uvWidth) {
                                val uIndex = uRowOffset + col * uvPixelStride
                                val vIndex = vRowOffset + col * uvPixelStride
                                if (pos + 1 < nv21.size && vIndex < v.size && uIndex < u.size) {
                                    nv21[pos++] = v[vIndex]
                                    nv21[pos++] = u[uIndex]
                                }
                            }
                        }

                        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
                        val outStream = ByteArrayOutputStream()
                        yuvImage.compressToJpeg(Rect(0, 0, width, height), quality, outStream)
                        val jpegBytes = outStream.toByteArray()

                        // Rotate bitmap if needed for camera orientation (standard portrait display, front mirror default)
                        val matrix = Matrix()
                        if (isFront) {
                            matrix.postRotate(270f)
                            matrix.postScale(-1f, 1f) // Natural front camera mirror mode
                        } else {
                            matrix.postRotate(90f)
                        }

                        val originalBmp = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
                        if (originalBmp != null) {
                            val rotatedBmp = Bitmap.createBitmap(originalBmp, 0, 0, originalBmp.width, originalBmp.height, matrix, true)
                            originalBmp.recycle()

                            val rotatedOut = ByteArrayOutputStream()
                            rotatedBmp.compress(Bitmap.CompressFormat.JPEG, quality, rotatedOut)
                            rotatedBmp.recycle()
                            result.success(rotatedOut.toByteArray())
                        } else {
                            result.success(jpegBytes)
                        }
                    } catch (e: Exception) {
                        result.error("CONVERT_ERROR", e.message, null)
                    }
                }
                "playCallTone" -> {
                    val type = call.argument<String>("type") ?: "stop"
                    handleCallTone(type)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Native System Notifications MethodChannel
        notificationMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
        notificationMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showCallNotification" -> {
                    val callId = call.argument<String>("callId") ?: ""
                    val callerName = call.argument<String>("callerName") ?: "Kontak"
                    val isVideo = call.argument<Boolean>("isVideo") ?: false
                    showSystemCallNotification(callId, callerName, isVideo)
                    result.success(true)
                }
                "showMessageNotification" -> {
                    val convId = call.argument<String>("conversationId") ?: ""
                    val title = call.argument<String>("title") ?: "Pesan Baru"
                    val message = call.argument<String>("message") ?: ""
                    showSystemMessageNotification(convId, title, message)
                    result.success(true)
                }
                "cancelNotification" -> {
                    val id = call.argument<Int>("id") ?: 9999
                    val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancel(id)
                    nm.cancel(8888)
                    nm.cancel(9999)
                    stopCurrentRingtone()
                    stopCallTone()
                    result.success(true)
                }
                "cancelAll" -> {
                    val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancelAll()
                    stopCurrentRingtone()
                    stopCallTone()
                    result.success(true)
                }
                "getLaunchPayload" -> {
                    val payload = launchPayload
                    launchPayload = null
                    result.success(payload)
                }
                "startBackgroundService" -> {
                    val baseUrl = call.argument<String>("baseUrl") ?: ""
                    val token = call.argument<String>("token") ?: ""
                    try {
                        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                        nm.cancel(LajuPushService.NOTIFICATION_ID_SYNC)
                        nm.cancel(9001)
                    } catch (_: Exception) {}
                    LajuPushService.startService(applicationContext, baseUrl, token)
                    result.success(true)
                }
                "stopBackgroundService" -> {
                    LajuPushService.stopService(applicationContext)
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val isIgnoring = powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
                        result.success(isIgnoring)
                    } else {
                        result.success(true)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                startActivity(fallbackIntent)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Native Location MethodChannel (OpenStreetMap compliant)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasLocationPermission" -> {
                    val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    result.success(fine || coarse)
                }
                "requestLocationPermission" -> {
                    val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    if (fine || coarse) {
                        result.success(true)
                    } else {
                        pendingLocationPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                            LOCATION_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "getCurrentLocation" -> {
                    fetchDeviceLocation(result)
                }
                "openMap" -> {
                    val lat = call.argument<Double>("latitude") ?: 0.0
                    val lng = call.argument<Double>("longitude") ?: 0.0
                    val label = call.argument<String>("label") ?: "Lokasi"
                    try {
                        val geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng(${Uri.encode(label)})")
                        val intent = Intent(Intent.ACTION_VIEW, geoUri)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                        } else {
                            val osmUri = Uri.parse("https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng")
                            val osmIntent = Intent(Intent.ACTION_VIEW, osmUri)
                            osmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(osmIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val osmUri = Uri.parse("https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng")
                            val osmIntent = Intent(Intent.ACTION_VIEW, osmUri)
                            osmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(osmIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("MAP_ERROR", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Hardware Device Unique ID MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getHardwareDeviceId" -> {
                    try {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        ) ?: ""
                        val manufacturer = Build.MANUFACTURER ?: "Android"
                        val model = Build.MODEL ?: "Device"
                        val deviceFingerprint = "${manufacturer}_${model}_${androidId}".trim()
                        result.success(deviceFingerprint)
                    } catch (e: Exception) {
                        result.success("android_${Build.MODEL}")
                    }
                }
                "getDeviceModelName" -> {
                    try {
                        val manufacturer = Build.MANUFACTURER?.replaceFirstChar {
                            if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
                        } ?: "Android"
                        val model = Build.MODEL ?: "Device"
                        result.success("$manufacturer $model".trim())
                    } catch (e: Exception) {
                        result.success("Android Device")
                    }
                }
                "getAppVersion" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        val vName = pInfo.versionName ?: "1.0.0"
                        val vCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode.toLong()
                        }
                        result.success(mapOf(
                            "versionName" to vName,
                            "versionCode" to vCode
                        ))
                    } catch (e: Exception) {
                        result.success(mapOf(
                            "versionName" to "1.0.0",
                            "versionCode" to 1L
                        ))
                    }
                }
                "getStorageStats" -> {
                    try {
                        val path = Environment.getDataDirectory()
                        val stat = StatFs(path.path)
                        val blockSize = stat.blockSizeLong
                        val totalBlocks = stat.blockCountLong
                        val availableBlocks = stat.availableBlocksLong

                        val totalBytes = totalBlocks * blockSize
                        val freeBytes = availableBlocks * blockSize
                        val usedBytes = totalBytes - freeBytes

                        result.success(mapOf(
                            "totalBytes" to totalBytes,
                            "freeBytes" to freeBytes,
                            "usedBytes" to usedBytes
                        ))
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                "openUrl" -> {
                    try {
                        val urlStr = call.argument<String>("url")
                        if (!urlStr.isNullOrEmpty()) {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(urlStr)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("OPEN_URL_ERROR", e.message, null)
                    }
                }
                "getApkDownloadPath" -> {
                    try {
                        val updateFile = File(cacheDir, "laju_update.apk")
                        result.success(updateFile.absolutePath)
                    } catch (e: Exception) {
                        result.error("PATH_ERROR", e.message, null)
                    }
                }
                "installApk" -> {
                    try {
                        val filePath = call.argument<String>("filePath") ?: File(cacheDir, "laju_update.apk").absolutePath
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file not found at $filePath", null)
                        } else {
                            val apkUri = FileProvider.getUriForFile(
                                this@MainActivity,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                "exportAccountReport" -> {
                    try {
                        val fileName = call.argument<String>("fileName") ?: "laju_account_report.json"
                        val content = call.argument<String>("content") ?: "{}"
                        val exportDir = File(filesDir, "exports")
                        if (!exportDir.exists()) exportDir.mkdirs()
                        val reportFile = File(exportDir, fileName)
                        reportFile.writeText(content, Charsets.UTF_8)

                        val uri = FileProvider.getUriForFile(
                            this@MainActivity,
                            "${applicationContext.packageName}.fileprovider",
                            reportFile
                        )
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "application/json"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            putExtra(Intent.EXTRA_SUBJECT, "Laporan Akun LAJU")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooser = Intent.createChooser(shareIntent, "Ekspor Laporan Akun LAJU").apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(chooser)
                        result.success(reportFile.absolutePath)
                    } catch (e: Exception) {
                        result.error("EXPORT_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun stopCurrentRingtone() {
        try {
            currentSystemRingtone?.stop()
            currentSystemRingtone = null
            currentAudioTrack?.apply {
                if (playState == AudioTrack.PLAYSTATE_PLAYING) {
                    stop()
                }
                release()
            }
            currentAudioTrack = null
        } catch (_: Exception) {}
    }

    private fun triggerVibrate(mode: String) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(VIBRATOR_SERVICE) as Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                when (mode) {
                    "Pendek" -> vibrator.vibrate(VibrationEffect.createOneShot(80, VibrationEffect.DEFAULT_AMPLITUDE))
                    "Panjang" -> vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 350, 150, 350), -1))
                    "Default" -> vibrator.vibrate(VibrationEffect.createOneShot(220, VibrationEffect.DEFAULT_AMPLITUDE))
                    "Mati" -> vibrator.cancel()
                    else -> vibrator.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE))
                }
            } else {
                @Suppress("DEPRECATION")
                when (mode) {
                    "Pendek" -> vibrator.vibrate(80)
                    "Panjang" -> vibrator.vibrate(longArrayOf(0, 350, 150, 350), -1)
                    "Default" -> vibrator.vibrate(220)
                    "Mati" -> vibrator.cancel()
                    else -> vibrator.vibrate(200)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun playSynthesizedRingtone(name: String) {
        Thread {
            try {
                stopCurrentRingtone()
                if (name.contains("Hening", ignoreCase = true) || name.contains("Mute", ignoreCase = true)) {
                    return@Thread
                }
                if (name.contains("Panggilan", ignoreCase = true) || name.contains("Call", ignoreCase = true)) {
                    val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    val ringtone = RingtoneManager.getRingtone(applicationContext, ringtoneUri)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        ringtone?.isLooping = true
                    }
                    ringtone?.play()
                    currentSystemRingtone = ringtone
                    return@Thread
                }

                val sampleRate = 44100
                val pcmData: ShortArray = when {
                    name.contains("Quantum", ignoreCase = true) -> generateArpeggio(sampleRate, doubleArrayOf(523.25, 659.25, 783.99, 1046.50), 0.12)
                    name.contains("Neon", ignoreCase = true) -> generateDualTone(sampleRate, 880.0, 1760.0, 0.32)
                    name.contains("Horizon", ignoreCase = true) -> generateChord(sampleRate, doubleArrayOf(440.0, 554.37, 659.25), 0.65)
                    name.contains("Emerald", ignoreCase = true) -> generateChime(sampleRate, doubleArrayOf(1318.5, 1567.98, 2093.0), 0.50)
                    name.contains("Cyber", ignoreCase = true) -> generateBeep(sampleRate, 987.77, 0.20)
                    name.contains("Aurora", ignoreCase = true) -> generateWarmPad(sampleRate, doubleArrayOf(329.63, 493.88, 659.25), 0.75)
                    name.contains("Celestial", ignoreCase = true) -> generateArpeggio(sampleRate, doubleArrayOf(587.33, 880.0, 1174.66, 1760.0), 0.14)
                    else -> {
                        val notificationUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        val ringtone = RingtoneManager.getRingtone(applicationContext, notificationUri)
                        ringtone?.play()
                        currentSystemRingtone = ringtone
                        return@Thread
                    }
                }

                val bufferSize = pcmData.size * 2
                val track = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    AudioTrack.Builder()
                        .setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                        )
                        .setAudioFormat(
                            AudioFormat.Builder()
                                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                                .setSampleRate(sampleRate)
                                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                                .build()
                        )
                        .setBufferSizeInBytes(bufferSize)
                        .setTransferMode(AudioTrack.MODE_STATIC)
                        .build()
                } else {
                    @Suppress("DEPRECATION")
                    AudioTrack(
                        android.media.AudioManager.STREAM_NOTIFICATION,
                        sampleRate,
                        AudioFormat.CHANNEL_OUT_MONO,
                        AudioFormat.ENCODING_PCM_16BIT,
                        bufferSize,
                        AudioTrack.MODE_STATIC
                    )
                }

                currentAudioTrack = track
                track.write(pcmData, 0, pcmData.size)
                track.play()
                Thread.sleep((pcmData.size.toDouble() / sampleRate * 1000).toLong() + 100)
                track.release()
                if (currentAudioTrack === track) {
                    currentAudioTrack = null
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun generateDualTone(sampleRate: Int, f1: Double, f2: Double, durationSec: Double): ShortArray {
        val numSamples = (durationSec * sampleRate).toInt()
        val buffer = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            val env = Math.exp(-4.0 * t / durationSec)
            val s = (Math.sin(2.0 * Math.PI * f1 * t) * 0.6 + Math.sin(2.0 * Math.PI * f2 * t) * 0.4) * env
            buffer[i] = (s * Short.MAX_VALUE * 0.75).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        return buffer
    }

    private fun generateArpeggio(sampleRate: Int, freqs: DoubleArray, noteDurationSec: Double): ShortArray {
        val totalSamples = (freqs.size * noteDurationSec * sampleRate).toInt()
        val buffer = ShortArray(totalSamples)
        val noteSamples = (noteDurationSec * sampleRate).toInt()

        for (n in freqs.indices) {
            val f = freqs[n]
            for (i in 0 until noteSamples) {
                val idx = n * noteSamples + i
                if (idx >= totalSamples) break
                val t = i.toDouble() / sampleRate
                val env = Math.exp(-3.0 * t / noteDurationSec)
                val s = (Math.sin(2.0 * Math.PI * f * t) + 0.25 * Math.sin(4.0 * Math.PI * f * t)) * env
                buffer[idx] = (s * Short.MAX_VALUE * 0.7).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
        }
        return buffer
    }

    private fun generateChord(sampleRate: Int, freqs: DoubleArray, durationSec: Double): ShortArray {
        val numSamples = (durationSec * sampleRate).toInt()
        val buffer = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            val env = Math.exp(-2.5 * t / durationSec)
            var s = 0.0
            for (f in freqs) {
                s += Math.sin(2.0 * Math.PI * f * t)
            }
            s = (s / freqs.size) * env
            buffer[i] = (s * Short.MAX_VALUE * 0.75).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        return buffer
    }

    private fun generateChime(sampleRate: Int, freqs: DoubleArray, durationSec: Double): ShortArray {
        val numSamples = (durationSec * sampleRate).toInt()
        val buffer = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            val env = Math.exp(-4.5 * t / durationSec)
            var s = 0.0
            for ((idx, f) in freqs.withIndex()) {
                val weight = 1.0 / (idx + 1)
                s += Math.sin(2.0 * Math.PI * f * t) * weight
            }
            s = s * env * 0.8
            buffer[i] = (s * Short.MAX_VALUE).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        return buffer
    }

    private fun generateBeep(sampleRate: Int, freq: Double, durationSec: Double): ShortArray {
        val numSamples = (durationSec * sampleRate).toInt()
        val buffer = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            val env = Math.exp(-5.0 * t / durationSec)
            val s = Math.sin(2.0 * Math.PI * freq * t) * env
            buffer[i] = (s * Short.MAX_VALUE * 0.8).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        return buffer
    }

    private fun generateWarmPad(sampleRate: Int, freqs: DoubleArray, durationSec: Double): ShortArray {
        val numSamples = (durationSec * sampleRate).toInt()
        val buffer = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            val attack = (t / 0.08).coerceAtMost(1.0)
            val decay = Math.exp(-2.0 * t / durationSec)
            val env = attack * decay
            var s = 0.0
            for (f in freqs) {
                s += Math.sin(2.0 * Math.PI * f * t)
            }
            s = (s / freqs.size) * env
            buffer[i] = (s * Short.MAX_VALUE * 0.75).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        return buffer
    }

    private fun compressAndDownsampleImage(sourcePath: String, maxDimension: Int = 1280, quality: Int = 82): String {
        return try {
            val sourceFile = File(sourcePath)
            if (!sourceFile.exists() || sourceFile.length() == 0L) return sourcePath

            // 1. Read EXIF orientation before any transformations
            val orientation = try {
                val exif = ExifInterface(sourceFile.absolutePath)
                exif.getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL
                )
            } catch (_: Exception) {
                ExifInterface.ORIENTATION_NORMAL
            }

            val options = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeFile(sourceFile.absolutePath, options)
            val width = options.outWidth
            val height = options.outHeight

            if (width <= 0 || height <= 0) return sourcePath

            var inSampleSize = 1
            while (width / inSampleSize > maxDimension * 1.5 || height / inSampleSize > maxDimension * 1.5) {
                inSampleSize *= 2
            }

            val decodeOptions = BitmapFactory.Options().apply {
                this.inSampleSize = inSampleSize
            }
            val decodedBitmap = BitmapFactory.decodeFile(sourceFile.absolutePath, decodeOptions)
                ?: return sourcePath

            // 2. Build rotation / flip matrix based on EXIF orientation tag
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> {
                    matrix.postRotate(90f)
                    matrix.postScale(-1f, 1f)
                }
                ExifInterface.ORIENTATION_TRANSVERSE -> {
                    matrix.postRotate(270f)
                    matrix.postScale(-1f, 1f)
                }
            }

            // 3. Apply matrix transformation to ensure the bitmap is oriented upright
            val orientedBitmap = if (!matrix.isIdentity) {
                val rotated = Bitmap.createBitmap(
                    decodedBitmap,
                    0,
                    0,
                    decodedBitmap.width,
                    decodedBitmap.height,
                    matrix,
                    true
                )
                if (rotated != decodedBitmap) {
                    decodedBitmap.recycle()
                }
                rotated
            } else {
                decodedBitmap
            }

            // 4. Downsample while preserving upright dimensions
            val scale = Math.min(
                maxDimension.toFloat() / orientedBitmap.width.toFloat(),
                maxDimension.toFloat() / orientedBitmap.height.toFloat()
            )
            val finalBitmap = if (scale < 1.0f) {
                val targetW = Math.max(1, (orientedBitmap.width * scale).toInt())
                val targetH = Math.max(1, (orientedBitmap.height * scale).toInt())
                val scaled = Bitmap.createScaledBitmap(orientedBitmap, targetW, targetH, true)
                if (scaled != orientedBitmap) {
                    orientedBitmap.recycle()
                }
                scaled
            } else {
                orientedBitmap
            }

            val compressedFile = File(externalCacheDir ?: cacheDir, "img_optimized_${System.currentTimeMillis()}.jpg")
            val fos = FileOutputStream(compressedFile)
            finalBitmap.compress(Bitmap.CompressFormat.JPEG, quality, fos)
            fos.flush()
            fos.close()

            if (finalBitmap != orientedBitmap) {
                orientedBitmap.recycle()
            }
            finalBitmap.recycle()

            compressedFile.absolutePath
        } catch (e: Exception) {
            sourcePath
        }
    }

    private fun launchSystemCamera() {
        try {
            val storageDir = externalCacheDir ?: cacheDir
            if (!storageDir.exists()) {
                storageDir.mkdirs()
            }
            val photoFile = File(storageDir, "camera_capture_${System.currentTimeMillis()}.jpg")
            if (!photoFile.exists()) {
                photoFile.createNewFile()
            }
            currentCameraCapturePath = photoFile.absolutePath
            val photoUri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                photoFile
            )
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
                clipData = ClipData.newUri(contentResolver, "camera_photo", photoUri)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            // Explicitly grant write URI permissions to resolving camera apps (Samsung Camera, etc.)
            val resolvedActivities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(
                    intent,
                    PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            }
            for (resolveInfo in resolvedActivities) {
                val packageName = resolveInfo.activityInfo.packageName
                grantUriPermission(
                    packageName,
                    photoUri,
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }

            startActivityForResult(intent, CAMERA_REQUEST_CODE)
        } catch (e: Exception) {
            try {
                val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                startActivityForResult(intent, CAMERA_REQUEST_CODE)
            } catch (e2: Exception) {
                pendingCameraResult?.error("CAMERA_ERROR", e2.message, null)
                pendingCameraResult = null
            }
        }
    }

    private fun launchSystemVideoCamera() {
        try {
            val storageDir = externalCacheDir ?: cacheDir
            if (!storageDir.exists()) {
                storageDir.mkdirs()
            }
            val videoFile = File(storageDir, "camera_video_${System.currentTimeMillis()}.mp4")
            if (!videoFile.exists()) {
                videoFile.createNewFile()
            }
            currentCameraCapturePath = videoFile.absolutePath
            val videoUri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                videoFile
            )
            val intent = Intent(MediaStore.ACTION_VIDEO_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, videoUri)
                putExtra(MediaStore.EXTRA_DURATION_LIMIT, 60) // Enforce 60s max video duration!
                putExtra(MediaStore.EXTRA_VIDEO_QUALITY, 1)
                clipData = ClipData.newUri(contentResolver, "camera_video", videoUri)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivityForResult(intent, VIDEO_CAMERA_REQUEST_CODE)
        } catch (e: Exception) {
            try {
                val intent = Intent(MediaStore.ACTION_VIDEO_CAPTURE).apply {
                    putExtra(MediaStore.EXTRA_DURATION_LIMIT, 60)
                }
                startActivityForResult(intent, VIDEO_CAMERA_REQUEST_CODE)
            } catch (e2: Exception) {
                pendingCameraResult?.error("VIDEO_CAMERA_ERROR", e2.message, null)
                pendingCameraResult = null
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RECORD_AUDIO_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingAudioPermissionResult?.success(granted)
            pendingAudioPermissionResult = null
            if (granted && pendingCallAudioArgs != null) {
                val args = pendingCallAudioArgs
                pendingCallAudioArgs = null
                if (args != null) {
                    startRealtimeCallAudio(
                        args["remoteIp"] as? String ?: "",
                        args["remotePort"] as? Int ?: 50005,
                        args["localPort"] as? Int ?: 50005,
                        args["isSpeaker"] as? Boolean ?: false,
                        args["baseUrl"] as? String ?: "",
                        args["callId"] as? String ?: "",
                        args["token"] as? String ?: ""
                    )
                }
            } else if (!granted) {
                pendingCallAudioArgs = null
            }
        } else if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingCameraPermissionResult?.success(granted)
            pendingCameraPermissionResult = null
            if (pendingCameraResult != null) {
                if (granted) {
                    launchSystemCamera()
                } else {
                    pendingCameraResult?.success(null)
                    pendingCameraResult = null
                }
            }
        } else if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingLocationPermissionResult?.success(granted)
            pendingLocationPermissionResult = null
        } else if (requestCode == STORAGE_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingStoragePermissionResult?.success(granted)
            pendingStoragePermissionResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CAMERA_REQUEST_CODE) {
            val capturedPath = currentCameraCapturePath
            if (resultCode == Activity.RESULT_OK) {
                val capturedFile = capturedPath?.let { File(it) }
                if (capturedFile != null && capturedFile.exists() && capturedFile.length() > 0) {
                    val optimized = compressAndDownsampleImage(capturedFile.absolutePath, maxDimension = 1280, quality = 82)
                    pendingCameraResult?.success(optimized)
                } else {
                    val imageBitmap = data?.extras?.get("data") as? Bitmap
                    if (imageBitmap != null) {
                        try {
                            val file = File(externalCacheDir ?: cacheDir, "camera_capture_${System.currentTimeMillis()}.jpg")
                            val out = FileOutputStream(file)
                            imageBitmap.compress(Bitmap.CompressFormat.JPEG, 82, out)
                            out.flush()
                            out.close()
                            val optimized = compressAndDownsampleImage(file.absolutePath, maxDimension = 1280, quality = 82)
                            pendingCameraResult?.success(optimized)
                        } catch (e: Exception) {
                            pendingCameraResult?.error("SAVE_FAILED", e.message, null)
                        }
                    } else if (data?.data != null) {
                        try {
                            val file = File(externalCacheDir ?: cacheDir, "camera_capture_${System.currentTimeMillis()}.jpg")
                            contentResolver.openInputStream(data.data!!)?.use { input ->
                                FileOutputStream(file).use { output ->
                                    input.copyTo(output)
                                }
                            }
                            val optimized = compressAndDownsampleImage(file.absolutePath, maxDimension = 1280, quality = 82)
                            pendingCameraResult?.success(optimized)
                        } catch (e: Exception) {
                            pendingCameraResult?.error("SAVE_FAILED", e.message, null)
                        }
                    } else {
                        pendingCameraResult?.success(null)
                    }
                }
            } else {
                // If user cancelled, clean up empty file
                capturedPath?.let { path ->
                    try {
                        val f = File(path)
                        if (f.exists() && f.length() == 0L) {
                            f.delete()
                        }
                    } catch (_: Exception) {}
                }
                pendingCameraResult?.success(null)
            }

            // Revoke uri permission if granted
            capturedPath?.let { path ->
                try {
                    val file = File(path)
                    val uri = FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
                    revokeUriPermission(uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } catch (_: Exception) {}
            }

            pendingCameraResult = null
            currentCameraCapturePath = null
        } else if (requestCode == GALLERY_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                try {
                    val file = File(externalCacheDir ?: cacheDir, "gallery_picked_${System.currentTimeMillis()}.jpg")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(file).use { output ->
                            input.copyTo(output)
                        }
                    }
                    val optimized = compressAndDownsampleImage(file.absolutePath, maxDimension = 1280, quality = 82)
                    pendingCameraResult?.success(optimized)
                } catch (e: Exception) {
                    pendingCameraResult?.error("GALLERY_READ_FAILED", e.message, null)
                }
            } else {
                pendingCameraResult?.success(null)
            }
            pendingCameraResult = null
        } else if (requestCode == VIDEO_CAMERA_REQUEST_CODE) {
            val capturedPath = currentCameraCapturePath
            if (resultCode == Activity.RESULT_OK) {
                var finalPath = capturedPath
                if (finalPath == null || !File(finalPath).exists() || File(finalPath).length() == 0L) {
                    if (data?.data != null) {
                        try {
                            val file = File(externalCacheDir ?: cacheDir, "camera_video_${System.currentTimeMillis()}.mp4")
                            contentResolver.openInputStream(data.data!!)?.use { input ->
                                FileOutputStream(file).use { output ->
                                    input.copyTo(output)
                                }
                            }
                            finalPath = file.absolutePath
                        } catch (_: Exception) {}
                    }
                }
                if (finalPath != null && File(finalPath).exists() && File(finalPath).length() > 0L) {
                    var durationMs = 0L
                    var thumbPath: String? = null
                    try {
                        val retriever = android.media.MediaMetadataRetriever()
                        retriever.setDataSource(finalPath)
                        val dStr = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)
                        durationMs = dStr?.toLongOrNull() ?: 0L
                        val frame = retriever.getFrameAtTime(1000000) ?: retriever.frameAtTime
                        if (frame != null) {
                            val tFile = File(externalCacheDir ?: cacheDir, "thumb_${System.currentTimeMillis()}.jpg")
                            val out = FileOutputStream(tFile)
                            frame.compress(Bitmap.CompressFormat.JPEG, 80, out)
                            out.flush()
                            out.close()
                            thumbPath = tFile.absolutePath
                        }
                        retriever.release()
                    } catch (_: Exception) {}

                    if (durationMs > 61500L) {
                        val res = HashMap<String, Any?>()
                        res["error"] = "DURATION_EXCEEDED"
                        res["durationSeconds"] = durationMs / 1000
                        res["maxDurationSeconds"] = 60
                        pendingCameraResult?.success(res)
                    } else {
                        val res = HashMap<String, Any?>()
                        res["path"] = finalPath
                        res["durationMs"] = durationMs
                        res["fileSize"] = File(finalPath).length()
                        res["thumbnailPath"] = thumbPath
                        pendingCameraResult?.success(res)
                    }
                } else {
                    pendingCameraResult?.success(null)
                }
            } else {
                pendingCameraResult?.success(null)
            }
            pendingCameraResult = null
            currentCameraCapturePath = null
        } else if (requestCode == VIDEO_GALLERY_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    val destFile = File(externalCacheDir ?: cacheDir, "gallery_video_${System.currentTimeMillis()}.mp4")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(destFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    var durationMs = 0L
                    var thumbPath: String? = null
                    try {
                        val retriever = android.media.MediaMetadataRetriever()
                        retriever.setDataSource(destFile.absolutePath)
                        val dStr = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)
                        durationMs = dStr?.toLongOrNull() ?: 0L
                        val frame = retriever.getFrameAtTime(1000000) ?: retriever.frameAtTime
                        if (frame != null) {
                            val tFile = File(externalCacheDir ?: cacheDir, "thumb_${System.currentTimeMillis()}.jpg")
                            val out = FileOutputStream(tFile)
                            frame.compress(Bitmap.CompressFormat.JPEG, 80, out)
                            out.flush()
                            out.close()
                            thumbPath = tFile.absolutePath
                        }
                        retriever.release()
                    } catch (_: Exception) {}

                    if (durationMs > 61500L) {
                        val res = HashMap<String, Any?>()
                        res["error"] = "DURATION_EXCEEDED"
                        res["durationSeconds"] = durationMs / 1000
                        res["maxDurationSeconds"] = 60
                        pendingCameraResult?.success(res)
                    } else {
                        val res = HashMap<String, Any?>()
                        res["path"] = destFile.absolutePath
                        res["durationMs"] = durationMs
                        res["fileSize"] = destFile.length()
                        res["thumbnailPath"] = thumbPath
                        pendingCameraResult?.success(res)
                    }
                } catch (e: Exception) {
                    pendingCameraResult?.error("VIDEO_READ_FAILED", e.message, null)
                }
            } else {
                pendingCameraResult?.success(null)
            }
            pendingCameraResult = null
        } else if (requestCode == DOCUMENT_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    var displayName = "Document_${System.currentTimeMillis()}"
                    var fileSize = 0L
                    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (cursor.moveToFirst()) {
                            if (nameIndex != -1) displayName = cursor.getString(nameIndex) ?: displayName
                            if (sizeIndex != -1) fileSize = cursor.getLong(sizeIndex)
                        }
                    }
                    val safeName = displayName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                    val destFile = File(cacheDir, "doc_${System.currentTimeMillis()}_$safeName")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(destFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    val res = HashMap<String, Any>()
                    res["path"] = destFile.absolutePath
                    res["name"] = displayName
                    res["size"] = if (fileSize > 0) fileSize else destFile.length()
                    pendingMediaResult?.success(res)
                } catch (e: Exception) {
                    pendingMediaResult?.error("DOC_READ_ERROR", e.message, null)
                }
            } else {
                pendingMediaResult?.success(null)
            }
            pendingMediaResult = null
        } else if (requestCode == AUDIO_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    var displayName = "Audio_${System.currentTimeMillis()}.m4a"
                    var fileSize = 0L
                    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (cursor.moveToFirst()) {
                            if (nameIndex != -1) displayName = cursor.getString(nameIndex) ?: displayName
                            if (sizeIndex != -1) fileSize = cursor.getLong(sizeIndex)
                        }
                    }
                    val safeName = displayName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                    val destFile = File(cacheDir, "aud_${System.currentTimeMillis()}_$safeName")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(destFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    val res = HashMap<String, Any>()
                    res["path"] = destFile.absolutePath
                    res["name"] = displayName
                    res["size"] = if (fileSize > 0) fileSize else destFile.length()
                    pendingMediaResult?.success(res)
                } catch (e: Exception) {
                    pendingMediaResult?.error("AUDIO_READ_ERROR", e.message, null)
                }
            } else {
                pendingMediaResult?.success(null)
            }
            pendingMediaResult = null
        } else if (requestCode == CONTACT_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val contactUri = data.data!!
                try {
                    var contactName = "Contact"
                    var contactNumber = ""
                    val projection = arrayOf(
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                        ContactsContract.CommonDataKinds.Phone.NUMBER
                    )
                    contentResolver.query(contactUri, projection, null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val nameIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                            val numberIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                            if (nameIdx != -1) contactName = cursor.getString(nameIdx) ?: contactName
                            if (numberIdx != -1) contactNumber = cursor.getString(numberIdx) ?: ""
                        }
                    }
                    val res = HashMap<String, Any>()
                    res["name"] = contactName
                    res["phone"] = contactNumber
                    pendingMediaResult?.success(res)
                } catch (e: Exception) {
                    pendingMediaResult?.error("CONTACT_READ_ERROR", e.message, null)
                }
            } else {
                pendingMediaResult?.success(null)
            }
            pendingMediaResult = null
        }
    }

    private fun getActiveLocalIpAddress(): String {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()
                if (iface.isLoopback || !iface.isUp) continue
                val addresses = iface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val addr = addresses.nextElement()
                    if (!addr.isLoopbackAddress && addr is java.net.Inet4Address) {
                        return addr.hostAddress ?: "127.0.0.1"
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return "127.0.0.1"
    }

    private fun setCallSpeakerphone(isSpeaker: Boolean) {
        try {
            isCallAudioSpeaker = isSpeaker
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (isSpeaker) {
                    val speakerDevice = audioManager.availableCommunicationDevices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                    }
                    if (speakerDevice != null) {
                        audioManager.setCommunicationDevice(speakerDevice)
                    }
                } else {
                    val earpieceDevice = audioManager.availableCommunicationDevices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
                    }
                    if (earpieceDevice != null) {
                        audioManager.setCommunicationDevice(earpieceDevice)
                    } else {
                        audioManager.clearCommunicationDevice()
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                audioManager.isSpeakerphoneOn = isSpeaker
            }
        } catch (_: Exception) {}
    }

    private fun handleCallTone(type: String) {
        when (type) {
            "ringback" -> startRingbackTone()
            "busy" -> playBusyTone()
            else -> stopCallTone()
        }
    }

    private fun stopCallTone() {
        isPlayingCallTone = false
        try {
            ringbackToneTrack?.apply {
                if (playState == AudioTrack.PLAYSTATE_PLAYING) stop()
                release()
            }
            ringbackToneTrack = null
        } catch (_: Exception) {}
    }

    private fun startRingbackTone() {
        stopCallTone()
        isPlayingCallTone = true
        Thread {
            try {
                val sampleRate = 16000
                // Dual tone (440Hz + 480Hz) 1.8s tone, 2.5s pause
                val durationSec = 1.8
                val numSamples = (sampleRate * durationSec).toInt()
                val samples = ShortArray(numSamples)
                for (i in 0 until numSamples) {
                    val t = i.toDouble() / sampleRate
                    val sample = 0.5 * Math.sin(2.0 * Math.PI * 440.0 * t) + 0.5 * Math.sin(2.0 * Math.PI * 480.0 * t)
                    samples[i] = (sample * 16000.0).toInt().toShort()
                }

                while (isPlayingCallTone) {
                    val track = AudioTrack(
                        AudioManager.STREAM_VOICE_CALL,
                        sampleRate,
                        AudioFormat.CHANNEL_OUT_MONO,
                        AudioFormat.ENCODING_PCM_16BIT,
                        samples.size * 2,
                        AudioTrack.MODE_STATIC
                    )
                    ringbackToneTrack = track
                    track.write(samples, 0, samples.size)
                    track.play()

                    val playTime = (durationSec * 1000).toLong()
                    val start = System.currentTimeMillis()
                    while (isPlayingCallTone && (System.currentTimeMillis() - start < playTime)) {
                        Thread.sleep(100)
                    }

                    track.release()
                    if (!isPlayingCallTone) break

                    val pauseStart = System.currentTimeMillis()
                    while (isPlayingCallTone && (System.currentTimeMillis() - pauseStart < 2500)) {
                        Thread.sleep(100)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun playBusyTone() {
        stopCallTone()
        Thread {
            try {
                val sampleRate = 16000
                // Busy tone (480Hz + 620Hz)
                val durationSec = 0.4
                val numSamples = (sampleRate * durationSec).toInt()
                val samples = ShortArray(numSamples)
                for (i in 0 until numSamples) {
                    val t = i.toDouble() / sampleRate
                    val sample = 0.5 * Math.sin(2.0 * Math.PI * 480.0 * t) + 0.5 * Math.sin(2.0 * Math.PI * 620.0 * t)
                    samples[i] = (sample * 18000.0).toInt().toShort()
                }

                for (cycle in 0..2) {
                    val track = AudioTrack(
                        AudioManager.STREAM_VOICE_CALL,
                        sampleRate,
                        AudioFormat.CHANNEL_OUT_MONO,
                        AudioFormat.ENCODING_PCM_16BIT,
                        samples.size * 2,
                        AudioTrack.MODE_STATIC
                    )
                    track.write(samples, 0, samples.size)
                    track.play()
                    Thread.sleep((durationSec * 1000).toLong())
                    track.release()
                    Thread.sleep(250)
                }
            } catch (_: Exception) {}
        }.start()
    }

    private fun startRealtimeCallAudio(
        remoteIp: String,
        remotePort: Int,
        localPort: Int,
        isSpeaker: Boolean,
        baseUrl: String = "",
        callId: String = "",
        token: String = ""
    ) {
        stopCallTone()
        stopRealtimeCallAudio()

        // Verify microphone permission before initializing audio hardware
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            pendingCallAudioArgs = mapOf(
                "remoteIp" to remoteIp,
                "remotePort" to remotePort,
                "localPort" to localPort,
                "isSpeaker" to isSpeaker,
                "baseUrl" to baseUrl,
                "callId" to callId,
                "token" to token
            )
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                RECORD_AUDIO_REQUEST_CODE
            )
            return
        }

        isCallAudioActive = true
        isCallAudioMuted = false
        isCallAudioSpeaker = isSpeaker
        callRemoteIp = remoteIp
        callRemotePort = remotePort
        audioPlaybackQueue.clear()

        val sampleRate = 16000
        val channelIn = AudioFormat.CHANNEL_IN_MONO
        val channelOut = AudioFormat.CHANNEL_OUT_MONO
        val encoding = AudioFormat.ENCODING_PCM_16BIT

        val cleanBase = if (baseUrl.endsWith("/")) baseUrl.substring(0, baseUrl.length - 1) else baseUrl
        val hasHttpRelay = cleanBase.isNotEmpty() && callId.isNotEmpty() && token.isNotEmpty()

        Thread {
            try {
                setCallSpeakerphone(isSpeaker)

                val minRecBuf = AudioRecord.getMinBufferSize(sampleRate, channelIn, encoding)
                val recBufSize = Math.max(minRecBuf * 4, 8192)

                // Initialize AudioRecord with multiple source fallbacks for maximum device compatibility
                var recorder: AudioRecord? = null
                val sources = intArrayOf(
                    MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                    MediaRecorder.AudioSource.MIC,
                    MediaRecorder.AudioSource.DEFAULT
                )
                for (source in sources) {
                    try {
                        val rec = AudioRecord(source, sampleRate, channelIn, encoding, recBufSize)
                        if (rec.state == AudioRecord.STATE_INITIALIZED) {
                            recorder = rec
                            break
                        } else {
                            rec.release()
                        }
                    } catch (_: Exception) {}
                }

                if (recorder == null) {
                    android.util.Log.e("MainActivity", "Failed to initialize AudioRecord with any source")
                    stopRealtimeCallAudio()
                    return@Thread
                }
                callAudioRecord = recorder

                try {
                    if (AcousticEchoCanceler.isAvailable()) {
                        aecEffect = AcousticEchoCanceler.create(recorder.audioSessionId)?.apply {
                            enabled = true
                        }
                    }
                    if (NoiseSuppressor.isAvailable()) {
                        nsEffect = NoiseSuppressor.create(recorder.audioSessionId)?.apply {
                            enabled = true
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }

                val minTrackBuf = AudioTrack.getMinBufferSize(sampleRate, channelOut, encoding)
                val trackBufSize = Math.max(minTrackBuf * 4, 16384)

                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()

                val audioFormat = AudioFormat.Builder()
                    .setEncoding(encoding)
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelOut)
                    .build()

                val track = AudioTrack.Builder()
                    .setAudioAttributes(audioAttributes)
                    .setAudioFormat(audioFormat)
                    .setBufferSizeInBytes(trackBufSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()

                if (track.state != AudioTrack.STATE_INITIALIZED) {
                    android.util.Log.e("MainActivity", "Failed to initialize AudioTrack")
                    try { track.release() } catch (_: Exception) {}
                    stopRealtimeCallAudio()
                    return@Thread
                }

                synchronized(audioTrackLock) {
                    callAudioTrack = track
                    try {
                        track.play()
                    } catch (_: Exception) {}
                }

                var socket: DatagramSocket? = null
                try {
                    socket = DatagramSocket(null).apply {
                        reuseAddress = true
                        broadcast = true
                        bind(InetSocketAddress(localPort))
                    }
                } catch (_: Exception) {
                    try {
                        socket = DatagramSocket().apply {
                            reuseAddress = true
                            broadcast = true
                        }
                    } catch (e2: Exception) {
                        e2.printStackTrace()
                    }
                }
                callAudioSocket = socket

                try {
                    recorder.startRecording()
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "startRecording failed: $e")
                }

                val audioSendQueue = java.util.concurrent.ConcurrentLinkedQueue<ByteArray>()

                // 1. Audio Playback Thread (dedicated single consumer for AudioTrack to eliminate SIGSEGV concurrency)
                Thread {
                    while (isCallAudioActive) {
                        try {
                            val chunk = audioPlaybackQueue.poll(40, java.util.concurrent.TimeUnit.MILLISECONDS)
                            if (chunk != null && chunk.isNotEmpty() && isCallAudioActive) {
                                synchronized(audioTrackLock) {
                                    val currentTrack = callAudioTrack
                                    if (currentTrack != null &&
                                        currentTrack.state == AudioTrack.STATE_INITIALIZED &&
                                        currentTrack.playState == AudioTrack.PLAYSTATE_PLAYING) {
                                        currentTrack.write(chunk, 0, chunk.size)
                                    }
                                }
                            }
                        } catch (_: Exception) {}
                    }
                }.start()

                // 2. Audio Capture loop (reads PCM from mic)
                Thread {
                    val sendBuffer = ByteArray(640) // 20ms of 16kHz 16-bit mono PCM
                    val httpAccumulator = java.io.ByteArrayOutputStream()
                    var lastFlushTime = System.currentTimeMillis()

                    while (isCallAudioActive && recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                        try {
                            val read = recorder.read(sendBuffer, 0, sendBuffer.size)
                            if (read > 0 && !isCallAudioMuted) {
                                val targetIp = callRemoteIp
                                val targetPort = callRemotePort

                                // Send UDP unicast if peer IP is known
                                if (socket != null && !socket.isClosed) {
                                    if (targetIp.isNotEmpty() && targetIp != "255.255.255.255") {
                                        try {
                                            val target = InetAddress.getByName(targetIp)
                                            val packet = DatagramPacket(sendBuffer, read, target, targetPort)
                                            socket.send(packet)
                                        } catch (_: Exception) {}
                                    }
                                    try {
                                        val bcast = InetAddress.getByName("255.255.255.255")
                                        val bcastPacket = DatagramPacket(sendBuffer, read, bcast, targetPort)
                                        socket.send(bcastPacket)
                                    } catch (_: Exception) {}
                                }

                                if (hasHttpRelay) {
                                    httpAccumulator.write(sendBuffer, 0, read)
                                    val now = System.currentTimeMillis()
                                    if (now - lastFlushTime >= 120 && httpAccumulator.size() > 0) {
                                        val chunk = httpAccumulator.toByteArray()
                                        httpAccumulator.reset()
                                        lastFlushTime = now
                                        if (audioSendQueue.size < 12) {
                                            audioSendQueue.offer(chunk)
                                        }
                                    }
                                }
                            } else if (read <= 0) {
                                Thread.sleep(10)
                            }
                        } catch (_: Exception) {
                            Thread.sleep(20)
                        }
                    }
                }.start()

                // 3. Persistent HTTP Audio Sender Worker Thread
                if (hasHttpRelay) {
                    Thread {
                        val postUrl = URL("$cleanBase/calls/$callId/audio-chunk")
                        while (isCallAudioActive) {
                            val chunk = audioSendQueue.poll()
                            if (chunk != null && chunk.isNotEmpty()) {
                                try {
                                    val b64 = android.util.Base64.encodeToString(chunk, android.util.Base64.NO_WRAP)
                                    val postObj = org.json.JSONObject().apply {
                                        put("chunk", b64)
                                    }
                                    val conn = (postUrl.openConnection() as HttpURLConnection).apply {
                                        requestMethod = "POST"
                                        setRequestProperty("Authorization", "Bearer $token")
                                        setRequestProperty("Content-Type", "application/json")
                                        setRequestProperty("Connection", "Keep-Alive")
                                        connectTimeout = 3000
                                        readTimeout = 3000
                                        doOutput = true
                                    }
                                    conn.outputStream.use { os ->
                                        os.write(postObj.toString().toByteArray())
                                    }
                                    conn.responseCode
                                    conn.disconnect()
                                } catch (_: Exception) {}
                            } else {
                                Thread.sleep(25)
                            }
                        }
                    }.start()
                }

                // 4. UDP Receiver thread (pushes into audioPlaybackQueue)
                if (socket != null) {
                    Thread {
                        val recvBuffer = ByteArray(1024)
                        val recvPacket = DatagramPacket(recvBuffer, recvBuffer.size)

                        while (isCallAudioActive && !socket.isClosed) {
                            try {
                                socket.receive(recvPacket)
                                if (recvPacket.length > 0) {
                                    val copy = recvPacket.data.copyOfRange(recvPacket.offset, recvPacket.offset + recvPacket.length)
                                    if (audioPlaybackQueue.size < 50) {
                                        audioPlaybackQueue.offer(copy)
                                    }
                                }
                            } catch (_: Exception) {}
                        }
                    }.start()
                }

                // 5. Persistent HTTP Audio Receiver thread (pushes into audioPlaybackQueue)
                if (hasHttpRelay) {
                    Thread {
                        val fetchUrl = URL("$cleanBase/calls/$callId/audio-chunks")
                        while (isCallAudioActive) {
                            try {
                                val conn = (fetchUrl.openConnection() as HttpURLConnection).apply {
                                    requestMethod = "GET"
                                    setRequestProperty("Authorization", "Bearer $token")
                                    setRequestProperty("Connection", "Keep-Alive")
                                    connectTimeout = 3000
                                    readTimeout = 3000
                                }
                                if (conn.responseCode == 200) {
                                    val body = conn.inputStream.bufferedReader().use { it.readText() }
                                    val obj = org.json.JSONObject(body)
                                    val chunks = obj.optJSONArray("chunks")
                                    if (chunks != null) {
                                        for (i in 0 until chunks.length()) {
                                            val b64 = chunks.getString(i)
                                            if (b64.isNotEmpty()) {
                                                val bytes = android.util.Base64.decode(b64, android.util.Base64.NO_WRAP)
                                                if (bytes.isNotEmpty() && audioPlaybackQueue.size < 50) {
                                                    audioPlaybackQueue.offer(bytes)
                                                }
                                            }
                                        }
                                    }
                                }
                                conn.disconnect()
                            } catch (_: Exception) {}

                            try {
                                Thread.sleep(90)
                            } catch (_: Exception) {}
                        }
                    }.start()
                }

            } catch (e: Exception) {
                e.printStackTrace()
                stopRealtimeCallAudio()
            }
        }.start()
    }

    private fun showSystemCallNotification(callId: String, callerName: String, isVideo: Boolean) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        val answerIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("laju_type", "call")
            putExtra("laju_id", callId)
            putExtra("laju_caller_name", callerName)
            putExtra("laju_is_video", isVideo)
            putExtra("laju_action", "answer")
        }
        val answerPendingIntent = PendingIntent.getActivity(
            this,
            101,
            answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val declineIntent = Intent(this, LajuPushService::class.java).apply {
            action = LajuPushService.ACTION_DECLINE
            putExtra("call_id", callId)
            putExtra("caller_name", callerName)
        }
        val declinePendingIntent = PendingIntent.getService(
            this,
            102,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID_CALLS)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(callerName)
            .setContentText(if (isVideo) "Panggilan video masuk..." else "Panggilan suara masuk...")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setSound(ringtoneUri)
            .setVibrate(longArrayOf(0, 800, 400, 800, 400, 800))
            .setFullScreenIntent(answerPendingIntent, true)
            .setContentIntent(answerPendingIntent)
            .setAutoCancel(true)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_call, "Jawab", answerPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Tolak", declinePendingIntent)

        nm.notify(9999, builder.build())
    }

    private fun showSystemMessageNotification(conversationId: String, title: String, message: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("laju_type", "chat")
            putExtra("laju_id", conversationId)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            conversationId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val msgUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID_MESSAGES)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setSound(msgUri)
            .setVibrate(longArrayOf(0, 250, 150, 250))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        nm.notify(conversationId.hashCode(), builder.build())
    }

    private fun stopRealtimeCallAudio() {
        isCallAudioActive = false
        audioPlaybackQueue.clear()

        synchronized(audioTrackLock) {
            try {
                callAudioTrack?.apply {
                    if (state == AudioTrack.STATE_INITIALIZED) {
                        try {
                            if (playState == AudioTrack.PLAYSTATE_PLAYING) {
                                pause()
                                flush()
                                stop()
                            }
                        } catch (_: Exception) {}
                        try {
                            release()
                        } catch (_: Exception) {}
                    }
                }
            } catch (_: Exception) {}
            callAudioTrack = null
        }

        try {
            callAudioRecord?.apply {
                if (state == AudioRecord.STATE_INITIALIZED) {
                    try {
                        if (recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                            stop()
                        }
                    } catch (_: Exception) {}
                    try {
                        release()
                    } catch (_: Exception) {}
                }
            }
            callAudioRecord = null
        } catch (_: Exception) {}

        try {
            aecEffect?.apply {
                enabled = false
                release()
            }
            aecEffect = null
        } catch (_: Exception) {}

        try {
            nsEffect?.apply {
                enabled = false
                release()
            }
            nsEffect = null
        } catch (_: Exception) {}

        try {
            callAudioSocket?.close()
            callAudioSocket = null
        } catch (_: Exception) {}

        try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_NORMAL
            audioManager.isSpeakerphoneOn = false
        } catch (_: Exception) {}
    }

    private fun fetchDeviceLocation(result: MethodChannel.Result) {
        val hasFine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val hasCoarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasFine && !hasCoarse) {
            result.error("PERMISSION_DENIED", "Izin lokasi belum diberikan", null)
            return
        }

        try {
            val lm = getSystemService(LOCATION_SERVICE) as? LocationManager
            if (lm == null) {
                result.error("NO_LOCATION_MANAGER", "LocationManager tidak tersedia", null)
                return
            }

            var bestLoc: Location? = null
            val providers = lm.getProviders(true)
            for (provider in providers) {
                try {
                    val l = lm.getLastKnownLocation(provider) ?: continue
                    if (bestLoc == null || l.accuracy < bestLoc.accuracy || l.time > bestLoc.time) {
                        bestLoc = l
                    }
                } catch (_: SecurityException) {}
            }

            if (bestLoc != null) {
                resolveAddressAndReturn(bestLoc, result)
                return
            }

            // If no cached fix, request single location update with timeout
            val handler = Handler(Looper.getMainLooper())
            var answered = false

            val listener = object : LocationListener {
                override fun onLocationChanged(loc: Location) {
                    if (!answered) {
                        answered = true
                        try { lm.removeUpdates(this) } catch (_: Exception) {}
                        resolveAddressAndReturn(loc, result)
                    }
                }
                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }

            val timeoutRunnable = Runnable {
                if (!answered) {
                    answered = true
                    try { lm.removeUpdates(listener) } catch (_: Exception) {}
                    val fallback = Location("default").apply {
                        latitude = -6.2088
                        longitude = 106.8456
                        accuracy = 100f
                    }
                    resolveAddressAndReturn(fallback, result)
                }
            }

            handler.postDelayed(timeoutRunnable, 3500)

            try {
                if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 0L, 0f, listener, Looper.getMainLooper())
                } else if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0L, 0f, listener, Looper.getMainLooper())
                }
            } catch (e: Exception) {
                if (!answered) {
                    answered = true
                    handler.removeCallbacks(timeoutRunnable)
                    result.error("LOCATION_REQUEST_FAILED", e.message, null)
                }
            }
        } catch (e: Exception) {
            result.error("LOCATION_ERROR", e.message, null)
        }
    }

    private fun resolveAddressAndReturn(loc: Location, result: MethodChannel.Result) {
        Thread {
            var name = "Lokasi Terkini"
            var address = String.format(Locale.US, "%.5f, %.5f", loc.latitude, loc.longitude)
            try {
                val geocoder = Geocoder(this, Locale("id", "ID"))
                @Suppress("DEPRECATION")
                val list = geocoder.getFromLocation(loc.latitude, loc.longitude, 1)
                if (!list.isNullOrEmpty()) {
                    val a = list[0]
                    val feature = a.featureName ?: ""
                    val thoroughfare = a.thoroughfare ?: ""
                    val subLocality = a.subLocality ?: ""
                    val locality = a.locality ?: ""
                    val subAdmin = a.subAdminArea ?: ""
                    val admin = a.adminArea ?: ""

                    name = if (feature.isNotBlank() && feature != thoroughfare) feature
                           else if (thoroughfare.isNotBlank()) thoroughfare
                           else if (subLocality.isNotBlank()) subLocality
                           else if (locality.isNotBlank()) locality
                           else "Lokasi Terkini"

                    val line = (0..a.maxAddressLineIndex).mapNotNull { a.getAddressLine(it) }.joinToString(", ")
                    address = if (line.isNotBlank()) line
                              else listOfNotNull(thoroughfare, subLocality, locality, subAdmin, admin)
                                  .filter { it.isNotBlank() }
                                  .joinToString(", ")
                }
            } catch (_: Exception) {}

            val data = mapOf(
                "latitude" to loc.latitude,
                "longitude" to loc.longitude,
                "accuracy" to loc.accuracy.toDouble(),
                "name" to name,
                "address" to address
            )

            runOnUiThread {
                result.success(data)
            }
        }.start()
    }
}

class NativeVideoPlayerView(
    context: Context,
    id: Int,
    private val params: Map<String, Any?>?,
    messenger: BinaryMessenger
) : PlatformView, MethodChannel.MethodCallHandler {

    private val container = FrameLayout(context)
    private val videoView = VideoView(context)
    private val channel = MethodChannel(messenger, "com.laju/native_video_view_$id")
    private var mediaPlayer: MediaPlayer? = null

    init {
        channel.setMethodCallHandler(this)
        container.setBackgroundColor(android.graphics.Color.BLACK)

        val layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        layoutParams.gravity = android.view.Gravity.CENTER
        videoView.layoutParams = layoutParams
        container.addView(videoView)

        videoView.setOnPreparedListener { mp ->
            mediaPlayer = mp
            val loop = (params?.get("loop") as? Boolean) ?: false
            mp.isLooping = loop
            val isMuted = (params?.get("muted") as? Boolean) ?: false
            if (isMuted) {
                mp.setVolume(0f, 0f)
            } else {
                mp.setVolume(1f, 1f)
            }

            channel.invokeMethod("onPrepared", mapOf(
                "durationMs" to mp.duration,
                "width" to mp.videoWidth,
                "height" to mp.videoHeight
            ))

            val autoPlay = (params?.get("autoPlay") as? Boolean) ?: true
            if (autoPlay) {
                videoView.start()
            }
        }

        videoView.setOnCompletionListener {
            channel.invokeMethod("onCompleted", null)
        }

        videoView.setOnErrorListener { _, what, extra ->
            channel.invokeMethod("onError", mapOf("what" to what, "extra" to extra))
            true
        }

        val videoSource = params?.get("url") as? String
        if (!videoSource.isNullOrEmpty()) {
            setSource(videoSource)
        }
    }

    private fun setSource(source: String) {
        try {
            if (source.startsWith("data:")) {
                try {
                    val rawB64 = if (source.contains(",")) source.substringAfter(",") else source
                    val videoBytes = android.util.Base64.decode(rawB64, android.util.Base64.DEFAULT)
                    val tempFile = File(context.cacheDir, "status_temp_video_${System.currentTimeMillis()}.mp4")
                    FileOutputStream(tempFile).use { out ->
                        out.write(videoBytes)
                    }
                    videoView.setVideoPath(tempFile.absolutePath)
                    return
                } catch (b64Err: Exception) {
                    android.util.Log.e("NativeVideoPlayerView", "Base64 video decode error: ${b64Err.message}")
                }
            }
            if (source.startsWith("http://") || source.startsWith("https://")) {
                videoView.setVideoURI(Uri.parse(source))
            } else {
                val f = File(source)
                if (f.exists()) {
                    videoView.setVideoPath(f.absolutePath)
                } else {
                    videoView.setVideoURI(Uri.parse(source))
                }
            }
        } catch (e: Exception) {
            channel.invokeMethod("onError", mapOf("error" to (e.message ?: "Failed to set source")))
        }
    }

    override fun getView(): View = container

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                videoView.start()
                result.success(true)
            }
            "pause" -> {
                videoView.pause()
                result.success(true)
            }
            "seekTo" -> {
                val pos = call.argument<Int>("positionMs") ?: 0
                videoView.seekTo(pos)
                result.success(true)
            }
            "setMuted" -> {
                val muted = call.argument<Boolean>("muted") ?: false
                try {
                    if (muted) {
                        mediaPlayer?.setVolume(0f, 0f)
                    } else {
                        mediaPlayer?.setVolume(1f, 1f)
                    }
                } catch (_: Exception) {}
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun dispose() {
        channel.setMethodCallHandler(null)
        try {
            videoView.stopPlayback()
        } catch (_: Exception) {}
        container.removeAllViews()
        mediaPlayer = null
    }
}

class NativeVideoPlayerFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?>
        return NativeVideoPlayerView(context, viewId, params, messenger)
    }
}
