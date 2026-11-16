package com.shubka.pleer;

import android.Manifest;
import android.app.Activity;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.hardware.Camera;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.ParcelFileDescriptor;
import android.provider.MediaStore;
import android.view.Gravity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.Toast;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** Простая запись видео с задней камеры, сохраняет в Movies/Pleer. */
public class CameraRecorderActivity extends Activity
        implements SurfaceHolder.Callback {

    private Camera camera;
    private SurfaceView surfaceView;
    private SurfaceHolder holder;
    private MediaRecorder mediaRecorder;
    private boolean recording = false;

    private Uri pendingVideoUri;
    private ParcelFileDescriptor outputPfd;

    private ImageButton btnToggle;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);

        FrameLayout preview = new FrameLayout(this);

        surfaceView = new SurfaceView(this);
        holder = surfaceView.getHolder();
        holder.addCallback(this);
        preview.addView(surfaceView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        btnToggle = new ImageButton(this);
        btnToggle.setImageResource(android.R.drawable.ic_btn_speak_now);
        btnToggle.setBackgroundColor(0x66000000);
        btnToggle.setOnClickListener(v -> toggleRecording());
        FrameLayout.LayoutParams btnLp = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        btnLp.bottomMargin = dp(48);
        preview.addView(btnToggle, btnLp);

        setContentView(preview);

        if (!hasPermissions()) {
            requestPermissions(
                    new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO}, 1);
        }
    }

    private boolean hasPermissions() {
        return checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
                && checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
    }

    @Override
    public void surfaceCreated(SurfaceHolder h) {
        if (!hasPermissions()) return;
        openCamera();
    }

    @Override
    public void surfaceChanged(SurfaceHolder h, int format, int width, int height) {
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder h) {
        stopPreviewAndRelease();
    }

    private void openCamera() {
        try {
            if (camera != null) camera.release();
            camera = Camera.open();
            camera.setDisplayOrientation(90);
            camera.setPreviewDisplay(holder);
            camera.startPreview();
        } catch (Exception e) {
            Toast.makeText(this, "Ошибка камеры", Toast.LENGTH_SHORT).show();
            finish();
        }
    }

    private String newFileName() {
        String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
        return "PleerCamera_" + stamp + ".mp4";
    }

    private boolean prepareRecorder() {
        try {
            if (camera != null) {
                camera.unlock();
            }
            mediaRecorder = new MediaRecorder();
            mediaRecorder.setCamera(camera);
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.CAMCORDER);
            mediaRecorder.setVideoSource(MediaRecorder.VideoSource.CAMERA);
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264);
            mediaRecorder.setVideoEncodingBitRate(6_000_000);
            mediaRecorder.setVideoFrameRate(30);
            mediaRecorder.setVideoSize(1280, 720);
            mediaRecorder.setOrientationHint(90);

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
                if (pendingVideoUri == null) return false;
                outputPfd = getContentResolver().openFileDescriptor(pendingVideoUri, "w");
                if (outputPfd == null) return false;
                mediaRecorder.setOutputFile(outputPfd.getFileDescriptor());
            } else {
                File dir = new File(
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
                        "Pleer");
                if (!dir.exists() && !dir.mkdirs()) return false;
                mediaRecorder.setOutputFile(new File(dir, newFileName()).getAbsolutePath());
            }

            mediaRecorder.setPreviewDisplay(holder.getSurface());
            mediaRecorder.prepare();
            return true;
        } catch (Exception e) {
            releaseRecorder();
            return false;
        }
    }

    private void startRecording() {
        if (!prepareRecorder()) {
            Toast.makeText(this, "Не удалось начать запись", Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            mediaRecorder.start();
            recording = true;
            btnToggle.setImageResource(android.R.drawable.ic_media_pause);
        } catch (Exception e) {
            Toast.makeText(this, "Ошибка записи", Toast.LENGTH_SHORT).show();
            releaseRecorder();
        }
    }

    private void stopRecording() {
        if (mediaRecorder != null) {
            try {
                mediaRecorder.stop();
            } catch (Exception ignored) {
            }
            releaseRecorder();
            finalizePending();
            recording = false;
            Toast.makeText(this, "Видео сохранено в Movies/Pleer", Toast.LENGTH_SHORT).show();
            btnToggle.setImageResource(android.R.drawable.ic_btn_speak_now);
            reopenCamera();
        }
    }

    private void finalizePending() {
        if (pendingVideoUri != null) {
            try {
                ContentValues values = new ContentValues();
                values.put(MediaStore.Video.Media.IS_PENDING, 0);
                getContentResolver().update(pendingVideoUri, values, null, null);
            } catch (Exception ignored) {
            }
            pendingVideoUri = null;
            outputPfd = null;
        }
    }

    private void reopenCamera() {
        if (!hasPermissions()) return;
        try {
            if (camera == null) {
                camera = Camera.open();
                camera.setDisplayOrientation(90);
                camera.setPreviewDisplay(holder);
                camera.startPreview();
            }
        } catch (Exception e) {
            camera = null;
        }
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

    private void stopPreviewAndRelease() {
        if (recording) {
            try {
                mediaRecorder.stop();
            } catch (Exception ignored) {
            }
            releaseRecorder();
            finalizePending();
            recording = false;
        }
        try {
            if (camera != null) {
                camera.stopPreview();
                camera.release();
            }
        } catch (Exception ignored) {
        }
        camera = null;
    }

    private void toggleRecording() {
        if (!hasPermissions()) return;
        if (recording) {
            stopRecording();
        } else {
            startRecording();
        }
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (hasPermissions()) openCamera();
    }

    @Override
    protected void onPause() {
        stopPreviewAndRelease();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        stopPreviewAndRelease();
        super.onDestroy();
    }
}