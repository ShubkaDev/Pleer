package com.shubka.pleer

/**
 * Связка «сервис записи экрана → Flutter».
 *
 * Сервис живёт отдельно от активити, поэтому все события (старт, ошибка,
 * остановка с путём к файлу) складываются сюда, а MainActivity передаёт их
 * в EventChannel, когда Flutter слушает.
 */
object ScreenRecordNotifier {
    var onEvent: ((Map<String, Any?>) -> Unit)? = null

    fun post(type: String, path: String?, message: String?, bubble: Boolean) {
        val event: Map<String, Any?> = mapOf(
            "type" to type,
            "path" to path,
            "message" to message,
            "bubble" to bubble
        )
        try {
            onEvent?.invoke(event)
        } catch (_: Exception) {
        }
    }
}
