package com.cbtsekolah.cbt_sekolah

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class CbtDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Menonaktifkan admin akan mematikan mode ujian"
    }
}
