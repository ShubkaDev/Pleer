package com.shubka.pleer;

import android.media.MediaMetadataRetriever;
import android.media.audiofx.AudioEffect;
import android.media.audiofx.BassBoost;
import android.media.audiofx.Equalizer;
import android.content.Context;
import android.media.AudioManager;
import android.os.Build;
import android.os.Environment;

import java.io.File;
import java.io.FileOutputStream;
import java.util.HashMap;
import java.util.Map;

/**
 * Нативная поддержка эквалайзера (5 полос + Bass Boost) и чтения/записи тегов.
 */
public class NativeAudioHelper {
    private Context context;

    private int audioSessionId = 0;
    private Equalizer equalizer;
    private BassBoost bassBoost;

    public NativeAudioHelper() {
        // контекст подставляется через кэш
    }

    public void setContext(Context ctx) {
        this.context = ctx;
    }

    public boolean enable() {
        release();
        try {
            AudioManager am = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            if (am != null) {
                audioSessionId = am.generateAudioSessionId();
            }
            equalizer = new Equalizer(0, audioSessionId);
            equalizer.setEnabled(true);
            bassBoost = new BassBoost(0, audioSessionId);
            bassBoost.setEnabled(true);
            return true;
        } catch (Exception e) {
            equalizer = null;
            bassBoost = null;
            return false;
        }
    }

    public void setBandLevel(int band, double gainDb) {
        if (equalizer == null) return;
        try {
            short[] range = equalizer.getBandLevelRange();
            short min = range[0];
            short max = range[1];
            float t = (float) ((gainDb + 15.0) / 30.0); // -15..15 -> 0..1
            short level = (short) (min + (max - min) * t);
            int bands = equalizer.getNumberOfBands();
            if (band >= 0 && band < bands) {
                equalizer.setBandLevel((short) band, level);
            }
        } catch (Exception ignored) {
        }
    }

    public void setBassBoost(int strength) {
        if (bassBoost == null) return;
        try {
            bassBoost.setStrength((short) strength);
        } catch (Exception ignored) {
        }
    }

    public void release() {
        try {
            if (equalizer != null) { equalizer.setEnabled(false); equalizer.release(); equalizer = null; }
            if (bassBoost != null) { bassBoost.setEnabled(false); bassBoost.release(); bassBoost = null; }
        } catch (Exception ignored) {
        }
    }

    public Map<String, Object> readTags(String path) {
        Map<String, Object> out = new HashMap<>();
        out.put("title", "");
        out.put("artist", "");
        out.put("album", "");
        out.put("artwork", null);

        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            File f = new File(path);
            if (!f.exists()) return out;
            retriever.setDataSource(path);
            out.put("title", nvl(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)));
            out.put("artist", nvl(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)));
            out.put("album", nvl(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)));
            byte[] art = retriever.getEmbeddedPicture();
            if (art != null && context != null) {
                File tmp = new File(context.getCacheDir(), "art_" + System.currentTimeMillis() + ".jpg");
                FileOutputStream fos = new FileOutputStream(tmp);
                fos.write(art);
                fos.close();
                out.put("artwork", tmp.getAbsolutePath());
            }
        } catch (Exception ignored) {
        } finally {
            try { retriever.release(); } catch (Exception ignored) {}
        }
        return out;
    }

    public boolean writeTags(String path, String title, String artist, String album) {
        // Для полной записи ID3 нужна сторонняя библиотека (jaudiotagger / mp3agic).
        // Базовая версия не перезаписывает теги, чтобы не повредить файл.
        return false; // заглушка
    }

    private String nvl(String s) {
        return s != null ? s : "";
    }
}