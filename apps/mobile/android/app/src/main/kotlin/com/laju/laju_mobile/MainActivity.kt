package com.laju.laju_mobile

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.RingtoneManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val CAMERA_CHANNEL = "com.laju/camera"
    private val VOICE_CHANNEL = "com.laju/voice_note"
    private val BIOMETRIC_CHANNEL = "com.laju/biometric"
    private val SOUND_CHANNEL = "com.laju/sound"
    private var currentAudioTrack: AudioTrack? = null

    private val CAMERA_REQUEST_CODE = 1001
    private val GALLERY_REQUEST_CODE = 1002
    private val RECORD_AUDIO_REQUEST_CODE = 1003
    private val DOCUMENT_REQUEST_CODE = 1004
    private val AUDIO_REQUEST_CODE = 1005
    private val CONTACT_REQUEST_CODE = 1006
    private val CAMERA_PERMISSION_REQUEST_CODE = 1007

    private var currentCameraCapturePath: String? = null
    private var pendingCameraResult: MethodChannel.Result? = null
    private var pendingMediaResult: MethodChannel.Result? = null
    private var pendingAudioPermissionResult: MethodChannel.Result? = null
    private var pendingCameraPermissionResult: MethodChannel.Result? = null

    private var mediaRecorder: MediaRecorder? = null
    private var currentRecordingFile: File? = null
    private var recordingStartTime: Long = 0L

    private var mediaPlayer: MediaPlayer? = null
    private var currentPlayingPath: String? = null
    private var voiceMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                "savePermanentAvatar" -> {
                    val srcPath = call.argument<String>("path")
                    if (srcPath != null) {
                        try {
                            val srcFile = File(srcPath)
                            if (srcFile.exists()) {
                                val destFile = File(filesDir, "user_avatar_${System.currentTimeMillis()}.jpg")
                                filesDir.listFiles()?.forEach { f ->
                                    if (f.name.startsWith("user_avatar_")) {
                                        f.delete()
                                    }
                                }
                                srcFile.copyTo(destFile, overwrite = true)
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
                    val filePath = call.argument<String>("filePath")
                    val title = call.argument<String>("title") ?: "Bagikan Kode QR LAJU"

                    try {
                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            if (text != null) {
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            if (filePath != null && File(filePath).exists()) {
                                val file = File(filePath)
                                val photoUri = FileProvider.getUriForFile(
                                    this@MainActivity,
                                    "${applicationContext.packageName}.fileprovider",
                                    file
                                )
                                clipData = ClipData.newUri(contentResolver, "qr_share", photoUri)
                                putExtra(Intent.EXTRA_STREAM, photoUri)
                                type = "image/*"
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

                                val resInfoList = packageManager.queryIntentActivities(this, PackageManager.MATCH_DEFAULT_ONLY)
                                for (resolveInfo in resInfoList) {
                                    val pkg = resolveInfo.activityInfo.packageName
                                    grantUriPermission(pkg, photoUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                            } else {
                                type = "text/plain"
                            }
                        }
                        val chooser = Intent.createChooser(sendIntent, title).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "shareContent error: ${e.message}", e)
                        result.error("SHARE_ERROR", e.message, null)
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
    }

    private fun stopCurrentRingtone() {
        try {
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
                val sampleRate = 44100
                val pcmData: ShortArray = when {
                    name.contains("Quantum", ignoreCase = true) -> generateArpeggio(sampleRate, doubleArrayOf(523.25, 659.25, 783.99, 1046.50), 0.12)
                    name.contains("Neon", ignoreCase = true) -> generateDualTone(sampleRate, 880.0, 1760.0, 0.32)
                    name.contains("Horizon", ignoreCase = true) -> generateChord(sampleRate, doubleArrayOf(440.0, 554.37, 659.25), 0.65)
                    name.contains("Emerald", ignoreCase = true) -> generateChime(sampleRate, doubleArrayOf(1318.5, 1567.98, 2093.0), 0.50)
                    name.contains("Cyber", ignoreCase = true) -> generateBeep(sampleRate, 987.77, 0.20)
                    name.contains("Aurora", ignoreCase = true) -> generateWarmPad(sampleRate, doubleArrayOf(329.63, 493.88, 659.25), 0.75)
                    name.contains("Celestial", ignoreCase = true) -> generateArpeggio(sampleRate, doubleArrayOf(587.33, 880.0, 1174.66, 1760.0), 0.14)
                    name.contains("Hening", ignoreCase = true) || name.contains("Mute", ignoreCase = true) -> return@Thread
                    else -> {
                        val notificationUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        val ringtone = RingtoneManager.getRingtone(applicationContext, notificationUri)
                        ringtone?.play()
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

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RECORD_AUDIO_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingAudioPermissionResult?.success(granted)
            pendingAudioPermissionResult = null
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
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CAMERA_REQUEST_CODE) {
            val capturedPath = currentCameraCapturePath
            if (resultCode == Activity.RESULT_OK) {
                val capturedFile = capturedPath?.let { File(it) }
                if (capturedFile != null && capturedFile.exists() && capturedFile.length() > 0) {
                    pendingCameraResult?.success(capturedFile.absolutePath)
                } else {
                    val imageBitmap = data?.extras?.get("data") as? Bitmap
                    if (imageBitmap != null) {
                        try {
                            val file = File(externalCacheDir ?: cacheDir, "camera_capture_${System.currentTimeMillis()}.jpg")
                            val out = FileOutputStream(file)
                            imageBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                            out.flush()
                            out.close()
                            pendingCameraResult?.success(file.absolutePath)
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
                            pendingCameraResult?.success(file.absolutePath)
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
                    pendingCameraResult?.success(file.absolutePath)
                } catch (e: Exception) {
                    pendingCameraResult?.error("GALLERY_READ_FAILED", e.message, null)
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

    override fun onDestroy() {
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
}
