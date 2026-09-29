package com.example.staylocal

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground service that keeps the process alive while a model loads or a
 * reply streams, so backgrounding the app does not freeze or kill on-device
 * generation. Started and stopped from Dart via the
 * "staylocal/foreground_generation" method channel; it runs only while the
 * chat controller is busy and never outlives the work.
 */
class ForegroundGenerationService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Generation",
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
            return Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_generation)
                .setContentTitle("StayLocal")
                .setContentText("Generating a reply on-device…")
                .setOngoing(true)
                .build()
        }
        @Suppress("DEPRECATION")
        return Notification.Builder(this)
            .setSmallIcon(R.drawable.ic_stat_generation)
            .setContentTitle("StayLocal")
            .setContentText("Generating a reply on-device…")
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "generation"
        private const val NOTIFICATION_ID = 1

        fun start(context: Context) {
            val intent = Intent(context, ForegroundGenerationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ForegroundGenerationService::class.java))
        }
    }
}
