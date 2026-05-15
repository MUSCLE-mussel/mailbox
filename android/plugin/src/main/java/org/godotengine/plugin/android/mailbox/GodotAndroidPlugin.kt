@file:Suppress("FunctionName", "PropertyName")

package org.godotengine.plugin.android.mailbox

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.util.Log
import android.view.View
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import org.godotengine.godot.Godot
import org.godotengine.godot.error.Error
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.godotengine.godot.utils.PermissionsUtil.requestPermissions
import java.util.concurrent.TimeUnit


@Suppress("unused")
class GodotAndroidPlugin(godot: Godot): GodotPlugin(godot)
{
    val POST_NOTIFICATIONS_PERMISSION = "android.permission.POST_NOTIFICATIONS"
    val POST_NOTIFICATIONS_PERMISSION_RESULT_RECEIVED_SIGNAL =
        SignalInfo("post_notifications_permission_result_received", Boolean::class.javaObjectType)
    val RESTART_REQUESTED_SIGNAL =
        SignalInfo("restart_requested")

    val MAIL_NOTIFICATION_CHANNEL_ID = "mail"

    override fun getPluginName() = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo?>
    {
        return setOf(
            POST_NOTIFICATIONS_PERMISSION_RESULT_RECEIVED_SIGNAL,
            RESTART_REQUESTED_SIGNAL,
        )
    }

    override fun onMainCreate(activity: Activity?): View?
    {
        val channel = NotificationChannel(
            MAIL_NOTIFICATION_CHANNEL_ID,
            "Mailbox",
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.description = "Notifications when new mail arrives"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)

        return null
    }

    override fun onMainPause() {}
    override fun onMainResume()
    {
        runOnHostThread {
            val shouldRestart = activity?.intent?.getBooleanExtra("should_restart", false) ?: false
            activity?.intent?.putExtra("should_restart", false)

            if (shouldRestart)
            {
                Log.d(pluginName, "emit RESTART_REQUESTED_SIGNAL")
                emitSignal(
                    godot, getPluginName(), RESTART_REQUESTED_SIGNAL
                )
            }
        }
    }
    override fun onMainDestroy() {}

    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?)
    {
//        Log.d(pluginName, "onMainActivityResult: $requestCode $resultCode $data")
    }

    override fun onMainRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String?>?,
        grantResults: IntArray?
    )
    {
        if (permissions == null) return
        if (grantResults == null) return

        for ((i, permission) in permissions.withIndex())
        {
            when (permission)
            {
                POST_NOTIFICATIONS_PERMISSION ->
                {
                    val result = grantResults[i] >= 0

                    emitSignal(
                        godot, getPluginName(), POST_NOTIFICATIONS_PERMISSION_RESULT_RECEIVED_SIGNAL,
                        result
                    )
                    Log.d(pluginName, "permission result: $result")
                }
            }
        }
//        Log.d(pluginName, "permission result: $requestCode $permissions $grantResults")
    }

    @UsedByGodot
    fun request_notifications_permission(): Boolean
    {
        Log.d(pluginName, "request permissions")
        return !requestPermissions(
            activity!!,
            listOf(POST_NOTIFICATIONS_PERMISSION)
        ) // returns true if permission is already granted, false otherwise
    }

    @UsedByGodot
    fun open_app_info_settings(): Int
    {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val uri = Uri.fromParts("package", activity!!.packageName, null)
            intent.data = uri
            activity!!.startActivity(intent)
        } catch (e: Exception) {
            Log.e(pluginName, "open_app_info_settings():: Failed due to " + e.message)
        }

        return Error.OK.toNativeValue()
    }

    @UsedByGodot
    fun hello_world()
    {
        runOnHostThread {
            Toast.makeText(activity, "Hello World 2", Toast.LENGTH_LONG).show()
            Log.d(pluginName, "Hello World")
        }
    }
    @UsedByGodot
    fun schedule_notification(delaySeconds: Int)
    {
        runOnHostThread {
            Log.d(pluginName, "queue notification: $delaySeconds")

            val inputData = workDataOf(
                "channel_id" to MAIL_NOTIFICATION_CHANNEL_ID
            )

            val workRequest =
                OneTimeWorkRequestBuilder<MailboxWorker>()
                    .setInitialDelay(delaySeconds.toLong(), TimeUnit.SECONDS)
                    .setInputData(inputData)
                    .build()

            WorkManager.getInstance(context)
                .enqueue(workRequest)
        }
    }


    @UsedByGodot
    fun test_notifications()
    {
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, MAIL_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_mail_outline)
            .setContentTitle("You've got mail")
            .setContentText("Check it out!")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(1, builder.build())
    }
}
