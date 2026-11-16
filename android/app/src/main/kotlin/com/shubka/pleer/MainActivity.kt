package com.shubka.pleer

import android.app.Activity
import android.app.PictureInPictureParams
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.util.Rational
import android.media.MediaScannerConnection
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private lateinit var nativeAudio: NativeAudioHelper

    // запись экрана
    private var projectionManager: MediaProjectionManager? = null
    private var recordEventSink: EventChannel.EventSink? = null

    // открытие медиафайлов извне
    private var intentEventSink: EventChannel.EventSink? = null
    private var pendingMedia: Map<String, String>? = null

    // Picture-in-Picture: по умолчанию выключен, включается экраном видео
    private var pipEnabled: Boolean = false

    // Идёт ли сейчас запись экрана (по событиям сервиса)
    private var screenRecordingActive: Boolean = false

    // Ожидающие ответа операции над медиафайлами (согласие пользователя, Android 11+)
    private var pendingRename: Triple<Uri, String, MethodChannel.Result>? = null
    private var pendingDelete: Pair<Uri, MethodChannel.Result>? = null

    override fun onCreate(bundle: android.os.Bundle?) {
        super.onCreate(bundle)
        projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        pendingMedia = extractMedia(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeAudio = NativeAudioHelper()
        nativeAudio.setContext(applicationContext)

        val messenger: BinaryMessenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "multitool.equalizer").setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> result.success(nativeAudio.enable())
                "setBandLevel" -> {
                    nativeAudio.setBandLevel(call.argument<Int>("band") ?: 0, call.argument<Double>("gain") ?: 0.0)
                    result.success(null)
                }
                "setBassBoost" -> {
                    nativeAudio.setBassBoost(call.argument<Int>("strength") ?: 0)
                    result.success(null)
                }
                "release" -> {
                    nativeAudio.release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "multitool.tags").setMethodCallHandler { call, result ->
            val path = call.argument<String>("path") ?: ""
            when (call.method) {
                "read" -> result.success(nativeAudio.readTags(path))
                "write" -> result.success(
                    nativeAudio.writeTags(
                        path,
                        call.argument<String>("title"),
                        call.argument<String>("artist"),
                        call.argument<String>("album")
                    )
                )
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "multitool.screen").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> startScreenRecording(call.argument<String>("output"), result)
                "stop" -> {
                    stopScreenRecording()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // События записи экрана
        EventChannel(messenger, "multitool.screen/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    recordEventSink = events
                    ScreenRecordNotifier.onEvent = { event ->
                        val type = event["type"] as? String
                        when (type) {
                            "started" -> screenRecordingActive = true
                            "stopped", "error" -> screenRecordingActive = false
                        }
                        try {
                            events?.success(event)
                        } catch (_: Exception) {
                            recordEventSink = null
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    recordEventSink = null
                    ScreenRecordNotifier.onEvent = null
                }
            }
        )

        // Разрешение «Поверх других приложений» для кружка остановки записи
        MethodChannel(messenger, "multitool.overlay").setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlay" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    } catch (_: Exception) {
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Запуск записи с камеры (нативная Activity)
        MethodChannel(messenger, "multitool.camera").setMethodCallHandler { call, result ->
            when (call.method) {
                "launch" -> {
                    try {
                        startActivity(Intent(this, CameraRecorderActivity::class.java))
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Переименование и удаление медиафайлов через MediaStore (Android 10+)
        MethodChannel(messenger, "multitool.media").setMethodCallHandler { call, result ->
            when (call.method) {
                "rename" -> {
                    val uriStr = call.argument<String>("uri")
                    val newName = call.argument<String>("newName")
                    renameMedia(uriStr, newName, result)
                }
                "delete" -> {
                    val uriStr = call.argument<String>("uri")
                    deleteMedia(uriStr, result)
                }
                else -> result.notImplemented()
            }
        }

        // Установка аудиофайла как мелодии звонка
        MethodChannel(messenger, "multitool.ringtone").setMethodCallHandler { call, result ->
            when (call.method) {
                "isWritable" -> {
                    val ok = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                        Settings.System.canWrite(this)
                    result.success(ok)
                }
                "requestWriteSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_WRITE_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        } catch (_: Exception) {
                        }
                    }
                    result.success(true)
                }
                "setRingtone" -> {
                    val uriStr = call.argument<String>("uri")
                    val ok = setAsRingtone(uriStr)
                    result.success(ok)
                }
                else -> result.notImplemented()
            }
        }

        // Picture-in-Picture: включается только с экрана видео
        MethodChannel(messenger, "multitool.pip").setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    pipEnabled = call.arguments as? Boolean ?: false
                    result.success(true)
                }
                "isSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    result.success(supported)
                }
                "enter" -> {
                    if (!pipEnabled) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(enterPipNow())
                }
                else -> result.notImplemented()
            }
        }

        // Открытие медиафайлов из проводника
        MethodChannel(messenger, "multitool.intent").setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialMedia" -> {
                    result.success(pendingMedia)
                    pendingMedia = null
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "multitool.intent/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    intentEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    intentEventSink = null
                }
            }
        )

        // Обновление виджета на главном экране
        MethodChannel(messenger, "multitool.widget").setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    getSharedPreferences("pleer_widget", Context.MODE_PRIVATE)
                        .edit()
                        .putString("title", title)
                        .putString("artist", artist)
                        .putBoolean("isPlaying", isPlaying)
                        .apply()
                    refreshWidget()
                    result.success(true)
                }
                "refresh" -> {
                    refreshWidget()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun refreshWidget() {
        try {
            val mgr = android.appwidget.AppWidgetManager.getInstance(applicationContext)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(applicationContext, PleerWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(applicationContext, PleerWidgetProvider::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                applicationContext.sendBroadcast(intent)
            }
        } catch (_: Exception) {
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val media = extractMedia(intent)
        if (media != null) {
            intentEventSink?.success(media)
        }
    }

    /** Извлекает URI и тип медиа из входящего intent (ACTION_VIEW / OPEN_DOCUMENT). */
    private fun extractMedia(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_OPEN_DOCUMENT) return null
        val uri = intent.data ?: return null
        val type = intent.type ?: guessType(uri.toString())
        return mapOf(
            "uri" to uri.toString(),
            "type" to type,
            "name" to (intent.data?.lastPathSegment ?: "")
        )
    }

    private fun guessType(path: String): String {
        val lower = path.lowercase()
        val videoExts = listOf(".mp4", ".mkv", ".3gp", ".webm", ".avi", ".mov", ".ts")
        return if (videoExts.any { lower.contains(it) }) "video/*" else "audio/*"
    }

    private fun startScreenRecording(outputPath: String?, result: MethodChannel.Result) {
        val pm = projectionManager ?: run {
            result.success(false)
            return
        }
        // Путь необязателен: сервис сам сохраняет видео в Movies/Pleer через MediaStore.
        // Запрос разрешения MediaProjection через системный диалог
        val intent = pm.createScreenCaptureIntent()
        startActivityForResult(intent, SCREEN_RECORD_REQUEST)
        pendingOutput = outputPath
        pendingResult = result
    }

    private fun stopScreenRecording() {
        if (!screenRecordingActive) {
            // Сервис не работает — просто синхронизируем состояние интерфейса.
            recordEventSink?.success(
                mapOf(
                    "type" to "stopped",
                    "path" to null,
                    "message" to null,
                    "bubble" to false
                )
            )
            return
        }
        val intent = Intent(this, ScreenRecordService::class.java).setAction(ScreenRecordService.ACTION_STOP)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            screenRecordingActive = false
            recordEventSink?.success(
                mapOf(
                    "type" to "stopped",
                    "path" to null,
                    "message" to null,
                    "bubble" to false
                )
            )
        }
        ScreenRecordService.sMediaProjection = null
    }

    /// Регистрирует записанный файл в MediaStore, чтобы он появился в галерее/медиатеке.
    private fun scanMedia(path: String) {
        MediaScannerConnection.scanFile(applicationContext, arrayOf(path), null) { _, uri ->
            // uri не используется, но можно уведомить Flutter при необходимости
        }
    }

    /// Переименовывает медиафайл через MediaStore (по content:// uri).
    /// На Android 11+ чужой файл требует одноразового согласия пользователя,
    /// поэтому операция может завершиться уже после ответа на диалог.
    private fun renameMedia(uriStr: String?, newName: String?, result: MethodChannel.Result) {
        if (uriStr.isNullOrBlank() || newName.isNullOrBlank()) {
            result.success(false)
            return
        }
        val uri = Uri.parse(uriStr)
        if (applyRename(uri, newName)) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pendingRename = Triple(uri, newName, result)
            try {
                val pi = MediaStore.createWriteRequest(contentResolver, listOf(uri))
                startIntentSenderForResult(pi.intentSender, WRITE_MEDIA_REQUEST, null, 0, 0, 0)
            } catch (e: Exception) {
                pendingRename = null
                result.success(false)
            }
        } else {
            result.success(false)
        }
    }

    private fun applyRename(uri: Uri, newName: String): Boolean = try {
        val values = android.content.ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, newName)
        }
        contentResolver.update(uri, values, null, null) > 0
    } catch (_: Exception) {
        false
    }

    /// Удаляет медиафайл через MediaStore (по content:// uri).
    private fun deleteMedia(uriStr: String?, result: MethodChannel.Result) {
        if (uriStr.isNullOrBlank()) {
            result.success(false)
            return
        }
        val uri = Uri.parse(uriStr)
        if (applyDelete(uri)) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pendingDelete = Pair(uri, result)
            try {
                val pi = MediaStore.createDeleteRequest(contentResolver, listOf(uri))
                startIntentSenderForResult(pi.intentSender, DELETE_MEDIA_REQUEST, null, 0, 0, 0)
            } catch (e: Exception) {
                pendingDelete = null
                result.success(false)
            }
        } else {
            result.success(false)
        }
    }

    private fun applyDelete(uri: Uri): Boolean = try {
        contentResolver.delete(uri, null, null) > 0
    } catch (_: Exception) {
        false
    }

    /// Устанавливает аудиофайл как мелодию звонка. Принимает content:// или file://.
    private fun setAsRingtone(uriStr: String?): Boolean {
        if (uriStr.isNullOrEmpty()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(this)) {
            return false
        }
        return try {
            val uri: Uri = when {
                uriStr.startsWith("content://") -> Uri.parse(uriStr)
                uriStr.startsWith("file://") -> Uri.parse(uriStr)
                else -> Uri.fromFile(java.io.File(uriStr))
            }
            // Пометка «это рингтон» не критична: для чужих файлов система
            // может её запретить, но саму мелодию всё равно можно назначить.
            try {
                contentResolver.update(
                    uri,
                    android.content.ContentValues().apply {
                        put(MediaStore.Audio.Media.IS_RINGTONE, 1)
                        put(MediaStore.Audio.Media.IS_ALARM, 0)
                        put(MediaStore.Audio.Media.IS_NOTIFICATION, 0)
                    },
                    null,
                    null
                )
            } catch (_: Exception) {
            }
            android.media.RingtoneManager.setActualDefaultRingtoneUri(
                this,
                android.media.RingtoneManager.TYPE_RINGTONE,
                uri
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        // Ответ на запрос согласия изменить/удалить чужой медиафайл (Android 11+).
        if (requestCode == WRITE_MEDIA_REQUEST) {
            val p = pendingRename
            pendingRename = null
            if (p != null) {
                val ok = resultCode == Activity.RESULT_OK && applyRename(p.first, p.second)
                p.third.success(ok)
            }
            return
        }
        if (requestCode == DELETE_MEDIA_REQUEST) {
            val p = pendingDelete
            pendingDelete = null
            if (p != null) {
                val ok = resultCode == Activity.RESULT_OK && applyDelete(p.first)
                p.second.success(ok)
            }
            return
        }

        if (requestCode == SCREEN_RECORD_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                // ВАЖНО: не берём проекцию здесь. На Android 14+ сервис должен
                // перейти в foreground (mediaProjection) ДО getMediaProjection.
                val svc = Intent(this, ScreenRecordService::class.java)
                    .setAction(ScreenRecordService.ACTION_START)
                    .putExtra("output", pendingOutput ?: "")
                    .putExtra("resultCode", resultCode)
                    .putExtra("data", data)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(svc)
                    } else {
                        startService(svc)
                    }
                    pendingResult?.success(true)
                } catch (e: Exception) {
                    pendingResult?.success(false)
                }
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
            pendingOutput = null
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Этот же колбэк приходит при блокировке экрана кнопкой питания.
        // В PiP уходим только если экран включён, то есть пользователь
        // действительно ушёл из приложения, а не погасил дисплей.
        if (!isScreenInteractive()) return
        enterPipIfPossible()
    }

    override fun onStop() {
        super.onStop()
        // Экран погас — снимаем флаг PiP, иначе окно остаётся пустым/свёрнутым
        // после повторного включения дисплея.
        if (!isScreenInteractive()) pipEnabled = false
    }

    private fun isScreenInteractive(): Boolean {
        return try {
            val pm = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
            pm?.isInteractive ?: true
        } catch (_: Exception) {
            true
        }
    }

    private fun enterPipIfPossible(): Boolean {
        if (!pipEnabled) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (!packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)) return false
        return enterPipNow()
    }

    private fun enterPipNow(): Boolean {
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            // Активность может не поддерживать PiP — не роняем приложение
            false
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }

    companion object {
        private const val SCREEN_RECORD_REQUEST = 1002
        private const val WRITE_MEDIA_REQUEST = 1003
        private const val DELETE_MEDIA_REQUEST = 1004
        private var pendingOutput: String? = null
        private var pendingResult: MethodChannel.Result? = null
    }

    override fun onDestroy() {
        nativeAudio.release()
        super.onDestroy()
    }
}