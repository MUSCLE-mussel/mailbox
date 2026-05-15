package org.godotengine.plugin.android.mailbox

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters

class MailboxWorker(context: Context, params: WorkerParameters) : Worker(context, params)
{
    override fun doWork(): Result {

        Log.d("mailbox", "worker start")

        showNotification()

        return Result.success()
    }

    private fun showNotification()
    {
        val intent = applicationContext.packageManager
            .getLaunchIntentForPackage(applicationContext.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK

                putExtra("should_restart", true)
            }

        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE
        )

        val channelId = inputData.getString("channel_id") ?: ""

        val builder = NotificationCompat.Builder(applicationContext, channelId)
            .setSmallIcon(R.drawable.ic_stat_mail_outline)
            .setContentTitle("You've got mail")
            .setContentText("Check it out!")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        val notificationManager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(1, builder.build())
    }
}