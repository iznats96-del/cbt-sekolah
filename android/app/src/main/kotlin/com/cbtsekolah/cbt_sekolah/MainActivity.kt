package com.cbtsekolah.cbt_sekolah

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.graphics.Rect
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cbtsekolah.cbt_sekolah/kiosk"
    private var isKioskLocked = false
    private var ch: MethodChannel? = null
    private var volumeObserver: ContentObserver? = null
    private val handler = Handler(Looper.getMainLooper())
    private var volumeEnforcer: Runnable? = null
    private var immersiveEnforcer: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        applyImmersive()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    private fun applyImmersive() {
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE)
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        // blok gesture nav (Android 10+): seluruh layar jadi exclusion
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                window.decorView.post {
                    val w = window.decorView.width
                    val h = window.decorView.height
                    if (w > 0 && h > 0) {
                        val rect = Rect(0, 0, w, h)
                        window.decorView.systemGestureExclusionRects = listOf(rect)
                    }
                }
            } catch (_: Exception) {}
        }
    }

    private fun startImmersiveEnforcer() {
        stopImmersiveEnforcer()
        immersiveEnforcer = object : Runnable {
            override fun run() {
                if (isKioskLocked) {
                    applyImmersive()
                    handler.postDelayed(this, 500)
                }
            }
        }
        handler.post(immersiveEnforcer!!)
    }

    private fun stopImmersiveEnforcer() {
        immersiveEnforcer?.let { handler.removeCallbacks(it) }
        immersiveEnforcer = null
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (isKioskLocked && hasFocus) {
            handler.postDelayed({ applyImmersive() }, 300)
            // balik fokus = kembali ke layar ujian -> alarm & volume-lock MATI lagi
            handler.postDelayed({
                stopVolumeEnforcer()
                try {
                    stopService(Intent(this, AlarmService::class.java))
                } catch (_: Exception) {}
            }, 250)
        }
        if (isKioskLocked && !hasFocus) {
            // tutup overlay/floating/chat head yang coba nimpa CBT
            try { sendBroadcast(Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)) } catch (_: Exception) {}
            handler.postDelayed({
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    am.moveTaskToFront(taskId, 0)
                } catch (_: Exception) {}
            }, 300)
            handler.postDelayed({
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    am.moveTaskToFront(taskId, 0)
                } catch (_: Exception) {}
            }, 800)
            reportIntrusion()
        }
    }

    private var lastIntrusionAt = 0L
    private fun reportIntrusion() {
        val now = System.currentTimeMillis()
        if (now - lastIntrusionAt < 3000) return
        lastIntrusionAt = now
        try {
            enforceMaxVolume()
            startVolumeEnforcer()
        } catch (_: Exception) {}
        try {
            val intent = Intent(this, AlarmService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
        } catch (_: Exception) {}
        try { ch?.invokeMethod("onIntrusion", null) } catch (_: Exception) {}
    }

    override fun onResume() {
        super.onResume()
        if (isKioskLocked) {
            applyImmersive()
            startImmersiveEnforcer()
        }
    }

    override fun onPause() {
        super.onPause()
        if (isKioskLocked) {
            handler.postDelayed({
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    am.moveTaskToFront(taskId, 0)
                } catch (_: Exception) {}
            }, 300)
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isKioskLocked) {
            reportIntrusion()
            handler.postDelayed({
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    am.moveTaskToFront(taskId, 0)
                } catch (_: Exception) {}
            }, 200)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isKioskLocked) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_BACK,
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_APP_SWITCH,
                KeyEvent.KEYCODE_MENU,
                KeyEvent.KEYCODE_DPAD_CENTER,
                KeyEvent.KEYCODE_SEARCH -> {
                    // blok tombol fisik / 3-button nav
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onBackPressed() {
        if (isKioskLocked) return
        super.onBackPressed()
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        if (isInMultiWindowMode) {
            // blok split/floating sebelum ujian juga, apalagi saat ujian
            handler.post {
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    am.moveTaskToFront(taskId, 0)
                } catch (_: Exception) {}
            }
            if (isKioskLocked) reportIntrusion()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ch!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.argument<Boolean>("secure") ?: false
                    if (secure) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                "enterKiosk" -> {
                    val ok = enterKioskMode()
                    result.success(ok)
                }
                "exitKiosk" -> {
                    exitKioskMode()
                    result.success(true)
                }
                "alarmStart" -> {
                    val maxVolume = call.argument<Boolean>("maxVolume") ?: true
                    val customPath = call.argument<String>("customPath")
                    startAlarm(maxVolume, customPath)
                    result.success(true)
                }
                "alarmStop" -> {
                    stopAlarm()
                    result.success(true)
                }
                "enforceVolume" -> {
                    enforceMaxVolume()
                    startVolumeEnforcer()
                    result.success(true)
                }
                "stopVolumeEnforcer" -> {
                    stopVolumeEnforcer()
                    result.success(true)
                }
                "isKioskActive" -> {
                    result.success(isKioskLocked)
                }
                "isDeviceOwner" -> {
                    result.success(isDeviceOwner())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isDeviceOwner(): Boolean {
        return try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            dpm.isDeviceOwnerApp(packageName)
        } catch (_: Exception) {
            false
        }
    }

    private fun enterKioskMode(): Boolean {
        isKioskLocked = true
        applyImmersive()
        startImmersiveEnforcer()
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val admin = ComponentName(this, CbtDeviceAdminReceiver::class.java)
            if (dpm.isDeviceOwnerApp(packageName)) {
                dpm.setStatusBarDisabled(admin, true)
                dpm.setKeyguardDisabled(admin, true)
                dpm.setCameraDisabled(admin, true)
                try {
                    dpm.setLockTaskPackages(admin, arrayOf(packageName))
                } catch (_: Exception) {}
                try {
                    dpm.setLockTaskFeatures(admin, DevicePolicyManager.LOCK_TASK_FEATURE_NONE)
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
        // hanya pakai LockTask kalau sudah device owner — kalau tidak, pinning dialog "App is pinned" akan muncul dan mengganggu
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && isDeviceOwner()) {
                startLockTask()
            }
        } catch (_: Exception) {}
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        return true
    }

    private fun exitKioskMode() {
        isKioskLocked = false
        stopVolumeEnforcer()
        stopImmersiveEnforcer()
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val admin = ComponentName(this, CbtDeviceAdminReceiver::class.java)
            if (dpm.isDeviceOwnerApp(packageName)) {
                dpm.setStatusBarDisabled(admin, false)
                dpm.setKeyguardDisabled(admin, false)
                dpm.setCameraDisabled(admin, false)
            }
        } catch (_: Exception) {}
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                stopLockTask()
            }
        } catch (_: Exception) {}
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
    }

    private fun enforceMaxVolume() {
        try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val streams = intArrayOf(
                AudioManager.STREAM_MUSIC,
                AudioManager.STREAM_ALARM,
                AudioManager.STREAM_NOTIFICATION,
                AudioManager.STREAM_RING,
                AudioManager.STREAM_SYSTEM
            )
            for (s in streams) {
                try {
                    val max = audio.getStreamMaxVolume(s)
                    audio.setStreamVolume(s, max, 0)
                } catch (_: Exception) {}
            }
            try {
                audio.setStreamVolume(AudioManager.STREAM_MUSIC, audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC), AudioManager.FLAG_SHOW_UI)
            } catch (_: Exception) {}
        } catch (_: Exception) {}
    }

    private fun startVolumeEnforcer() {
        stopVolumeEnforcer()
        volumeObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean) {
                if (isKioskLocked) enforceMaxVolume()
            }
        }
        try {
            contentResolver.registerContentObserver(Settings.System.CONTENT_URI, true, volumeObserver!!)
        } catch (_: Exception) {}
        volumeEnforcer = object : Runnable {
            override fun run() {
                if (isKioskLocked) {
                    enforceMaxVolume()
                    handler.postDelayed(this, 1500)
                }
            }
        }
        handler.post(volumeEnforcer!!)
    }

    private fun stopVolumeEnforcer() {
        volumeEnforcer?.let { handler.removeCallbacks(it) }
        volumeEnforcer = null
        volumeObserver?.let {
            try { contentResolver.unregisterContentObserver(it) } catch (_: Exception) {}
        }
        volumeObserver = null
    }

    private fun startAlarm(maxVolume: Boolean, customPath: String? = null) {
        try {
            if (maxVolume) enforceMaxVolume()
            if (maxVolume) startVolumeEnforcer()
        } catch (_: Exception) {}
        var path = customPath
        if (path.isNullOrEmpty()) {
            path = findCustomAlarmFile()
        }
        val intent = Intent(this, AlarmService::class.java).apply {
            putExtra("customPath", path)
            putExtra("maxVolume", maxVolume)
        }
        if (Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun findCustomAlarmFile(): String? {
        val candidates = listOf(
            "/sdcard/Download/4_5948414805994900225.mp3",
            "/sdcard/Download/4_5948414805994900225.ogg",
            "/sdcard/Music/4_5948414805994900225.mp3",
            "/storage/emulated/0/Download/4_5948414805994900225.mp3",
            filesDir.absolutePath + "/4_5948414805994900225.mp3",
            cacheDir.absolutePath + "/4_5948414805994900225.mp3"
        )
        for (p in candidates) {
            try {
                val f = java.io.File(p)
                if (f.exists() && f.canRead() && f.length() > 1024) return f.absolutePath
            } catch (_: Exception) {}
        }
        try {
            val dir = getExternalFilesDir(null)
            if (dir != null) {
                dir.listFiles()?.forEach { f ->
                    if (f.name.contains("59484") && f.length() > 1024) return f.absolutePath
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private fun stopAlarm() {
        stopService(Intent(this, AlarmService::class.java))
    }

    override fun onDestroy() {
        if (!isKioskLocked) stopAlarm()
        stopVolumeEnforcer()
        stopImmersiveEnforcer()
        super.onDestroy()
    }
}
