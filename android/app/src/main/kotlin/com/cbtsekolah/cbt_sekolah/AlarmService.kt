package com.cbtsekolah.cbt_sekolah

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.net.Uri

class AlarmService : Service() {
    private var player: MediaPlayer? = null

    companion object {
        const val CHANNEL_ID = "cbt_alarm"
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(1, buildNotification())
    }

    private fun createChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Peringatan Keluar", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarm peringatan saat meninggalkan ujian"
                setSound(null, null)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("DILARANG MENINGGALKAN UJIAN!")
            .setContentText("Kembalilah ke aplikasi ujian sekarang.")
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_MAX)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        playAlarm()
        vibrate()
        return START_STICKY
    }

    private fun playAlarm() {
        try {
            stopAudio()
            val player = MediaPlayer.create(this, Uri.parse("android.resource://${packageName}/${R.raw.alarm}"))
            player.isLooping = true
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            player.start()
            this.player = player
        } catch (_: Exception) {}
    }

    private fun vibrate() {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 800, 400, 800), 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 800, 400, 800), 0)
            }
        } catch (_: Exception) {}
    }

    private fun stopAudio() {
        try {
            player?.stop()
            player?.release()
            player = null
        } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopAudio()
        super.onDestroy()
    }
}