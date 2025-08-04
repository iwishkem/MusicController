package kemplayer.iwishkem.com.tr

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        // This is required for MediaSessionManager to work
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // This is required for MediaSessionManager to work
    }
}