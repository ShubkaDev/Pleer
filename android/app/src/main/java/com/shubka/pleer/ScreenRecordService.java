package com.shubka.pleer;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ServiceInfo;
import android.graphics.drawable.GradientDrawable;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.media.MediaRecorder;
import android.media.projection.MediaProjection;
import android.media.projection.MediaProjectionManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.provider.MediaStore;
import android.provider.Settings;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Фоновая запись экрана через MediaProjection.
 *
 * Ключевые моменты:
 *  - на Android 14+ сервис обязан выйти в foreground с типом mediaProjection
 *    ДО вызова getMediaProjection, иначе SecurityException;
 *  - видео сохраняется в MediaStore (Movies/Pleer) на API 29+ и в общую папку
 *    Movies/Pleer на более старых версиях — файл сразу виден в галерее и в плеере;
 *  - остановить запись можно кружком на экране или кнопкой «Стоп» в уведомлении;
 *  - все состояния (старт/ошибка/стоп) транслируются в Flutter через
 *    ScreenRecordNotifier, поэтому интерфейс никогда не «зависает».
 */
public class ScreenRecordService extends Service {
    private static final String TAG = "ScreenRecordService";

    /** Оставлено для совместимости; не используется напрямую. */
    public static MediaProjection sMediaProjection;

    static final String ACTION_START = "com.shubka.pleer.START_RECORD";
    static final String ACTION_STOP = "com.shubka.pleer.STOP_RECORD";
    private static final String ACTION_STOP_FROM_NOTIF = "com.shubka.pleer.STOP_FROM_NOTIF";
    private static final String CHANNEL_ID = "screen_record";
    private static final int NOTIF_ID = 1001;

    private MediaProjection mediaProjection;
    private VirtualDisplay virtualDisplay;
    private MediaRecorder mediaRecorder;
    private String outputPath;

    private Uri pendingVideoUri;
    private ParcelFileDescriptor outputPfd;

    private WindowManager bubbleWindowManager;
    private View bubbleView;
    private WindowManager.LayoutParams bubbleParams;

    private BroadcastReceiver stopReceiver;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        registerStopReceiver();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "Запись экрана",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setShowBadge(false);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(channel);
        }
    }

    private PendingIntent stopPendingIntent() {
        Intent intent = new Intent(ACTION_STOP_FROM_NOTIF).setPackage(getPackageName());
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return PendingIntent.getBroadcast(this, 42, intent, flags);
    }

    private PendingIntent openAppPendingIntent() {
        Intent intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return intent == null ? null : PendingIntent.getActivity(this, 43, intent, flags);
    }

    @SuppressWarnings("deprecation")
    private Notification buildNotification() {
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, CHANNEL_ID);
        } else {
            builder = new Notification.Builder(this);
        }
        builder.setContentTitle("Идёт запись экрана")
                .setContentText("Нажмите «Стоп», чтобы завершить и сохранить видео")
                .setSmallIcon(android.R.drawable.presence_video_online)
                .setOngoing(true);
        PendingIntent open = openAppPendingIntent();
        if (open != null) builder.setContentIntent(open);
        builder.addAction(
                android.R.drawable.ic_media_pause,
                "Стоп",
                stopPendingIntent()
        );
        return builder.build();
    }

    private boolean goForeground() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                        NOTIF_ID,
                        buildNotification(),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                );
            } else {
                startForeground(NOTIF_ID, buildNotification());
            }
            return true;
        } catch (Exception e) {
            Log.w(TAG, "goForeground failed", e);
            return false;
        }
    }

    private void registerStopReceiver() {
        try {
            stopReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    finishRecording("stopped");
                }
            };
            IntentFilter filter = new IntentFilter(ACTION_STOP_FROM_NOTIF);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(stopReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
            } else {
                registerReceiver(stopReceiver, filter);
            }
        } catch (Exception e) {
            Log.w(TAG, "registerStopReceiver failed", e);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_NOT_STICKY;
        String action = intent.getAction();

        if (ACTION_STOP.equals(action) || ACTION_STOP_FROM_NOTIF.equals(action)) {
            finishRecording("stopped");
            return START_NOT_STICKY;
        }

        if (!ACTION_START.equals(action)) return START_NOT_STICKY;

        // 1) Сначала foreground с типом mediaProjection.
        if (!goForeground()) {
            post("error", null, "Не удалось запустить фоновую запись экрана", false);
            stopSelf();
            return START_NOT_STICKY;
        }

        outputPath = intent.getStringExtra("output");
        int resultCode = intent.getIntExtra("resultCode", 0);
        Intent data = parcelableIntent(intent);

        if (data == null) {
            post("error", null, "Нет данных для захвата экрана", false);
            stopSelf();
            return START_NOT_STICKY;
        }

        // 2) Только теперь берём проекцию.
        try {
            MediaProjectionManager pm =
                    (MediaProjectionManager) getSystemService(Context.MEDIA_PROJECTION_SERVICE);
            if (pm == null) throw new IllegalStateException("MediaProjectionManager недоступен");
            mediaProjection = pm.getMediaProjection(resultCode, data);
        } catch (Exception e) {
            Log.w(TAG, "getMediaProjection failed", e);
            mediaProjection = null;
        }

        if (mediaProjection == null) {
            post("error", null, "Система не дала доступ к экрану", false);
            stopSelf();
            return START_NOT_STICKY;
        }

        // 3) Callback: пользователь остановил запись из системного UI.
        try {
            mediaProjection.registerCallback(new MediaProjection.Callback() {
                @Override
                public void onStop() {
                    finishRecording("stopped");
                }
            }, new Handler(Looper.getMainLooper()));
        } catch (Exception ignored) {
        }

        boolean ok = startRecording(mediaProjection);
        if (!ok) {
            finishRecording("error", "Не удалось начать запись экрана");
            return START_NOT_STICKY;
        }
        return START_STICKY;
    }

    private Intent parcelableIntent(Intent intent) {
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                return intent.getParcelableExtra("data", Intent.class);
            } else {
                //noinspection deprecation
                return intent.getParcelableExtra("data");
            }
        } catch (Exception e) {
            return null;
        }
    }

    private String newFileName() {
        String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
        return "Pleer_" + stamp + ".mp4";
    }

    /** Готовит файл/запись в MediaStore и настраивает MediaRecorder. */
    @SuppressWarnings("deprecation")
    private void prepareOutput(MediaRecorder recorder) throws Exception {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Video.Media.DISPLAY_NAME, newFileName());
            values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
            values.put(MediaStore.Video.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_MOVIES + "/Pleer");
            values.put(MediaStore.Video.Media.IS_PENDING, 1);
            Uri collection = MediaStore.Video.Media.getContentUri(
                    MediaStore.VOLUME_EXTERNAL_PRIMARY);
            pendingVideoUri = getContentResolver().insert(collection, values);
            if (pendingVideoUri == null) throw new IllegalStateException("MediaStore не создал файл");
            outputPfd = getContentResolver().openFileDescriptor(pendingVideoUri, "w");
            if (outputPfd == null) throw new IllegalStateException("Нет доступа к файлу записи");
            recorder.setOutputFile(outputPfd.getFileDescriptor());
        } else {
            File dir = new File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
                    "Pleer");
            if (!dir.exists() && !dir.mkdirs()) {
                // запасной вариант — папка во внутреннем хранилище приложения
                File fallback = getExternalFilesDir(Environment.DIRECTORY_MOVIES);
                if (fallback == null) fallback = getFilesDir();
                dir = fallback;
                if (!dir.exists() && !dir.mkdirs()) {
                    throw new IllegalStateException("Не удалось создать папку для записи");
                }
            }
            File file = new File(dir, newFileName());
            outputPath = file.getAbsolutePath();
            recorder.setOutputFile(outputPath);
        }
    }

    @SuppressWarnings("deprecation")
    private boolean startRecording(MediaProjection projection) {
        try {
            WindowManager wm = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
            DisplayMetrics metrics = new DisplayMetrics();
            wm.getDefaultDisplay().getRealMetrics(metrics);
            int width = metrics.widthPixels;
            int height = metrics.heightPixels;
            int densityDpi = metrics.densityDpi;

            // чётные размеры — требование некоторых кодировщиков
            width = (width % 2 == 0) ? width : width - 1;
            height = (height % 2 == 0) ? height : height - 1;

            mediaRecorder = new MediaRecorder();
            mediaRecorder.setVideoSource(MediaRecorder.VideoSource.SURFACE);
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264);
            mediaRecorder.setVideoEncodingBitRate(6_000_000);
            mediaRecorder.setVideoFrameRate(30);
            mediaRecorder.setVideoSize(width, height);
            prepareOutput(mediaRecorder);

            mediaRecorder.setOnErrorListener((mr, what, extra) -> {
                Log.w(TAG, "MediaRecorder error " + what + "/" + extra);
                finishRecording("error", "Ошибка кодирования видео (" + what + ")");
            });

            mediaRecorder.prepare();

            // ВАЖНО: на Android 14+ виртуальный дисплей для записи экрана нужно
            // создавать через MediaProjection. DisplayManager.createVirtualDisplay()
            // не передаёт токен проекции и падает с SecurityException
            // (requires CAPTURE_VIDEO_OUTPUT or an appropriate MediaProjection token).
            virtualDisplay = projection.createVirtualDisplay(
                    "PleerScreenRecorder",
                    width,
                    height,
                    densityDpi,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                    mediaRecorder.getSurface(),
                    null,
                    null
            );
            mediaRecorder.start();

            boolean bubble = showBubble();
            post("started", null, null, bubble);
            return true;
        } catch (Exception e) {
            Log.w(TAG, "startRecording failed", e);
            post("error", null, "Не удалось начать запись: " + e.getMessage(), false);
            releaseRecorder();
            return false;
        }
    }

    /** Останавливает запись, фиксирует файл и сообщает результат во Flutter. */
    private void finishRecording(String type) {
        finishRecording(type, null);
    }

    private void finishRecording(String type, String errorMessage) {
        String saved = closeRecording();
        hideBubble();

        if ("error".equals(type)) {
            post("error", null, errorMessage, false);
        } else if (saved != null && !saved.isEmpty()) {
            post("stopped", saved, null, false);
        } else {
            post("error", null, "Запись слишком короткая — файл не сохранён", false);
        }
        try {
            stopForeground(true);
        } catch (Exception ignored) {
        }
        stopSelf();
    }

    /** Завершает запись и возвращает путь/URI сохранённого файла или null. */
    private String closeRecording() {
        String result = null;
        if (mediaRecorder != null) {
            try {
                mediaRecorder.stop();
                result = (pendingVideoUri != null) ? pendingVideoUri.toString() : outputPath;
            } catch (Exception e) {
                // stop() бросает исключение, если запись слишком короткая
                Log.w(TAG, "mediaRecorder.stop failed", e);
                result = null;
            }
            releaseRecorder();
        }

        // Убеждаемся, что файл действительно содержит видео.
        if (result != null) {
            long size = sizeOf(result);
            Log.i(TAG, "recording finished: " + result + ", size=" + size + " bytes");
            if (size <= 0) {
                result = null;
            }
        }

        if (pendingVideoUri != null) {
            try {
                if (result == null) {
                    getContentResolver().delete(pendingVideoUri, null, null);
                } else {
                    ContentValues values = new ContentValues();
                    values.put(MediaStore.Video.Media.IS_PENDING, 0);
                    getContentResolver().update(pendingVideoUri, values, null, null);
                }
            } catch (Exception e) {
                Log.w(TAG, "finalize MediaStore item failed", e);
            }
            pendingVideoUri = null;
        }

        if (result != null && result.startsWith("/")) {
            // файл вне MediaStore — просим систему проиндексировать его
            try {
                android.media.MediaScannerConnection.scanFile(
                        getApplicationContext(), new String[]{result}, null, null);
            } catch (Exception ignored) {
            }
        }

        try {
            if (virtualDisplay != null) {
                virtualDisplay.release();
                virtualDisplay = null;
            }
        } catch (Exception ignored) {
        }
        try {
            if (mediaProjection != null) {
                mediaProjection.stop();
                mediaProjection = null;
            }
        } catch (Exception ignored) {
        }
        return result;
    }

    private void releaseRecorder() {
        try {
            if (mediaRecorder != null) {
                mediaRecorder.reset();
                mediaRecorder.release();
            }
        } catch (Exception ignored) {
        }
        mediaRecorder = null;
        try {
            if (outputPfd != null) outputPfd.close();
        } catch (Exception ignored) {
        }
        outputPfd = null;
    }

    /** Размер записанного файла (для content:// и обычных путей). -1 при ошибке. */
    private long sizeOf(String pathOrUri) {
        try {
            if (pathOrUri.startsWith("content://")) {
                try (ParcelFileDescriptor p =
                             getContentResolver().openFileDescriptor(Uri.parse(pathOrUri), "r")) {
                    return p == null ? -1 : p.getStatSize();
                }
            }
            return new File(pathOrUri).length();
        } catch (Exception e) {
            Log.w(TAG, "sizeOf failed for " + pathOrUri, e);
            return -1;
        }
    }

    private void post(String type, String path, String message, boolean bubble) {
        try {
            ScreenRecordNotifier.INSTANCE.post(type, path, message, bubble);
        } catch (Throwable ignored) {
        }
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density);
    }

    /** Плавающий кружок: перетаскивается, короткий тап — остановить запись. */
    private boolean showBubble() {
        try {
            if (bubbleView != null) return true;
            if (!Settings.canDrawOverlays(this)) {
                Log.w(TAG, "overlay permission is not granted");
                return false;
            }

            bubbleWindowManager = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
            if (bubbleWindowManager == null) return false;

            FrameLayout container = new FrameLayout(this);
            GradientDrawable bg = new GradientDrawable(
                    GradientDrawable.Orientation.TL_BR,
                    new int[]{0xFF5716FF, 0xFFA62AFF, 0xFFE439B3});
            bg.setShape(GradientDrawable.OVAL);
            bg.setStroke(dp(2), 0x99FFFFFF);
            container.setBackground(bg);
            container.setAlpha(0.92f);

            // Белый квадратик «стоп» по центру.
            View dot = new View(this);
            GradientDrawable dotBg = new GradientDrawable();
            dotBg.setShape(GradientDrawable.RECTANGLE);
            dotBg.setCornerRadius(dp(4));
            dotBg.setColor(0xFFFFFFFF);
            dot.setBackground(dotBg);
            FrameLayout.LayoutParams dotLp =
                    new FrameLayout.LayoutParams(dp(18), dp(18), Gravity.CENTER);
            container.addView(dot, dotLp);

            int size = dp(62);
            int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                    ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    : WindowManager.LayoutParams.TYPE_PHONE;
            bubbleParams = new WindowManager.LayoutParams(
                    size, size, flags,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                            | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    android.graphics.PixelFormat.TRANSLUCENT);
            bubbleParams.gravity = Gravity.TOP | Gravity.START;
            bubbleParams.x = dp(12);
            bubbleParams.y = dp(120);

            final float[] downRaw = new float[2];
            final int[] startPos = new int[2];
            final long[] downTime = new long[1];
            final boolean[] moved = new boolean[1];

            container.setOnTouchListener(new View.OnTouchListener() {
                @Override
                public boolean onTouch(View v, MotionEvent event) {
                    switch (event.getActionMasked()) {
                        case MotionEvent.ACTION_DOWN:
                            downRaw[0] = event.getRawX();
                            downRaw[1] = event.getRawY();
                            startPos[0] = bubbleParams.x;
                            startPos[1] = bubbleParams.y;
                            downTime[0] = System.currentTimeMillis();
                            moved[0] = false;
                            return true;
                        case MotionEvent.ACTION_MOVE:
                            float dx = event.getRawX() - downRaw[0];
                            float dy = event.getRawY() - downRaw[1];
                            if (Math.abs(dx) > dp(8) || Math.abs(dy) > dp(8)) {
                                moved[0] = true;
                            }
                            bubbleParams.x = startPos[0] + (int) dx;
                            bubbleParams.y = startPos[1] + (int) dy;
                            try {
                                bubbleWindowManager.updateViewLayout(bubbleView, bubbleParams);
                            } catch (Exception ignored) {
                            }
                            return true;
                        case MotionEvent.ACTION_UP:
                            long dt = System.currentTimeMillis() - downTime[0];
                            if (!moved[0] && dt < 400) {
                                finishRecording("stopped");
                            }
                            return true;
                        default:
                            return false;
                    }
                }
            });

            bubbleView = container;
            bubbleWindowManager.addView(bubbleView, bubbleParams);
            return true;
        } catch (Exception e) {
            Log.w(TAG, "showBubble failed", e);
            bubbleView = null;
            return false;
        }
    }

    private void hideBubble() {
        try {
            if (bubbleView != null && bubbleWindowManager != null) {
                bubbleWindowManager.removeView(bubbleView);
            }
        } catch (Exception ignored) {
        }
        bubbleView = null;
        bubbleWindowManager = null;
    }

    @Override
    public void onDestroy() {
        try {
            if (stopReceiver != null) unregisterReceiver(stopReceiver);
        } catch (Exception ignored) {
        }
        stopReceiver = null;
        if (mediaRecorder != null || mediaProjection != null) {
            finishRecording("stopped");
        }
        hideBubble();
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
