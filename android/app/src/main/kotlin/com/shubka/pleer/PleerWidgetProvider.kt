package com.shubka.pleer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.view.KeyEvent
import android.widget.RemoteViews

/**
 * Мини-виджет Pleer на главный экран.
 * Данные (трек/исполнитель) читаются из SharedPreferences("pleer_widget"),
 * которые пишет приложение. Кнопки шлют медиа-кнопки, которые ловит audio_service.
 */
class PleerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PLAY_PAUSE -> dispatchKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            ACTION_NEXT -> dispatchKey(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            ACTION_PREV -> dispatchKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            ACTION_REFRESH -> refresh(context)
        }
    }

    private fun dispatchKey(context: Context, keyCode: Int) {
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
        } catch (_: Exception) {
        }
        refresh(context)
    }

    private fun refresh(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, PleerWidgetProvider::class.java))
        for (id in ids) mgr.updateAppWidget(id, buildViews(context))
    }

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.pleer_widget)

        val prefs = context.getSharedPreferences("pleer_widget", Context.MODE_PRIVATE)
        val title = prefs.getString("title", "Pleer") ?: "Pleer"
        val artist = prefs.getString("artist", "Нажмите, чтобы открыть") ?: "Нажмите, чтобы открыть"
        val isPlaying = prefs.getBoolean("isPlaying", false)

        views.setTextViewText(R.id.widget_title, if (title.isBlank()) "Pleer" else title)
        views.setTextViewText(R.id.widget_artist, if (artist.isBlank()) "Pleer" else artist)

        views.setImageViewResource(
            R.id.widget_play,
            if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        )

        views.setOnClickPendingIntent(R.id.widget_play, pending(context, ACTION_PLAY_PAUSE))
        views.setOnClickPendingIntent(R.id.widget_next, pending(context, ACTION_NEXT))

        // Клик по самому виджету открывает приложение.
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            val pi = PendingIntent.getActivity(
                context, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_note, pi)
            views.setOnClickPendingIntent(R.id.widget_title, pi)
            views.setOnClickPendingIntent(R.id.widget_artist, pi)
        }
        return views
    }

    private fun pending(context: Context, action: String): PendingIntent {
        val intent = Intent(context, PleerWidgetProvider::class.java).setAction(action)
        return PendingIntent.getBroadcast(
            context, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    companion object {
        const val ACTION_PLAY_PAUSE = "com.shubka.pleer.WIDGET_PLAY_PAUSE"
        const val ACTION_NEXT = "com.shubka.pleer.WIDGET_NEXT"
        const val ACTION_PREV = "com.shubka.pleer.WIDGET_PREV"
        const val ACTION_REFRESH = "com.shubka.pleer.WIDGET_REFRESH"
    }
}