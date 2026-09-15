package com.cbtsekolah.cbt_sekolah

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.net.Uri
import java.io.File

class AlarmService : Service() {
    private var player: MediaPlayer? = null
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private val volumeRunnable = object : Runnable {
        override fun run() {
            enforceMaxVolume()
            handler.postDelayed(this, 1200)
        }
    }

    companion object {
        const val CHANNEL_ID = "cbt_alarm"
        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createChannel()
        startForeground(1, buildNotification())
        enforceMaxVolume()
        handler.post(volumeRunnable)
    }

    private fun enforceMaxVolume() {
        try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val streams = intArrayOf(
                AudioManager.STREAM_MUSIC,
                AudioManager.STREAM_ALARM,
                AudioManager.STREAM_NOTIFICATION,
                AudioManager.STREAM_RING
            )
            for (s in streams) {
                try {
                    audio.setStreamVolume(s, audio.getStreamMaxVolume(s), 0)
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    private fun createChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Peringatan Keluar", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarm peringatan saat meninggalkan ujian - matikan dengan kembali ke aplikasi"
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠️ UJIAN BERLANGSUNG - JANGAN TUTUP")
            .setContentText("Kembali ke aplikasi untuk mematikan alarm. Volume dipaksa maksimal.")
            .setContentIntent(pi)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(Notification.PRIORITY_MAX)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val customPath = intent?.getStringExtra("customPath")
        val maxVolume = intent?.getBooleanExtra("maxVolume", true) ?: true
        if (maxVolume) enforceMaxVolume()
        playAlarm(customPath)
        vibrate()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val restart = Intent(applicationContext, AlarmService::class.java)
        restart.`package` = packageName
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(restart)
            } else {
                startService(restart)
            }
        } catch (_: Exception) {}
        super.onTaskRemoved(rootIntent)
    }

    private fun playAlarm(customPath: String? = null) {
        try {
            stopAudio()
            val player = MediaPlayer()
            var success = false

            if (!customPath.isNullOrEmpty()) {
                try {
                    val file = File(customPath)
                    if (file.exists() && file.canRead()) {
                        player.setDataSource(file.absolutePath)
                        success = true
                    }
                } catch (_: Exception) {}
                if (!success) {
                    try {
                        val uri = Uri.parse(customPath)
                        player.setDataSource(this, uri)
                        success = true
                    } catch (_: Exception) {}
                }
            }

            if (!success) {
                try {
                    val afd = resources.openRawResourceFd(R.raw.alarm_custom)
                    player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                    success = true
                } catch (_: Exception) {}
            }
            if (!success) {
                try {
                    val afd = resources.openRawResourceFd(R.raw.alarm)
                    player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                    success = true
                } catch (_: Exception) {
                    try {
                        player.setDataSource(this, Uri.parse("android.resource://${packageName}/${R.raw.alarm}"))
                        success = true
                    } catch (_: Exception) {}
                }
            }

            if (!success) return

            player.isLooping = true
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            try {
                player.setVolume(1.0f, 1.0f)
            } catch (_: Exception) {}
            player.prepare()
            player.start()
            this.player = player
            enforceMaxVolume()
        } catch (_: Exception) {
            try {
                val fallback = MediaPlayer.create(this, Uri.parse("android.resource://${packageName}/${R.raw.alarm}"))
                fallback?.isLooping = true
                fallback?.start()
                this.player = fallback
            } catch (_: Exception) {}
        }
    }

    private fun vibrate() {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 800, 400, 800, 400, 1000), 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 800, 400, 800, 400, 1000), 0)
            }
        } catch (_: Exception) {}
    }

    private fun stopAudio() {
        try {
            player?.stop()
            player?.release()
            player = null
        } catch (_: Exception) {}
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.cancel()
        } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(volumeRunnable)
        stopAudio()
        isRunning = false
        super.onDestroy()
    }
}
