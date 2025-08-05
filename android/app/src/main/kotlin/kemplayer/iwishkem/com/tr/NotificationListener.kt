package kemplayer.iwishkem.com.tr

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        // İstersen burada bildirim bazlı ekstra işlem yapabilirsin
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // İstersen burada da bildirim silme takibi yapılabilir
    }
}