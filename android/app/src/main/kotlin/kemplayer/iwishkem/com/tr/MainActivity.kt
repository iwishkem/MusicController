package kemplayer.iwishkem.com.tr

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Bundle
import android.provider.Settings
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "kemplayer/media"
    private lateinit var mediaSessionManager: MediaSessionManager
    private var mediaController: MediaController? = null
    private var methodChannel: MethodChannel? = null

    private val mediaControllerCallback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            sendMediaInfoToFlutter()
        }

        override fun onPlaybackStateChanged(state: PlaybackState?) {
            sendMediaInfoToFlutter()
        }
    }

    private val sessionListener = object : MediaSessionManager.OnActiveSessionsChangedListener {
        override fun onActiveSessionsChanged(controllers: MutableList<MediaController>?) {
            mediaController?.unregisterCallback(mediaControllerCallback)
            mediaController = controllers?.firstOrNull()
            mediaController?.registerCallback(mediaControllerCallback)
            sendMediaInfoToFlutter()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getMediaInfo" -> {
                    checkAndRequestPermission()
                    result.success(getCurrentMediaInfo())
                }
                "mediaControl" -> {
                    val command = call.argument<String>("command")
                    handleMediaControl(command)
                    result.success(null)
                }
                "seekTo" -> {
                    val pos = call.argument<Number>("position")?.toLong()
                    if (pos != null) {
                        mediaController?.transportControls?.seekTo(pos)
                    }
                    result.success(null)
                }
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "openApp" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg != null) {
                        try {
                            startActivity(packageManager.getLaunchIntentForPackage(pkg))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Cannot open app", null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
        setupMediaSessionListener()
    }

    private fun checkAndRequestPermission() {
        val componentName = ComponentName(this, NotificationListener::class.java)
        val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        val isEnabled = enabledListeners != null && enabledListeners.contains(componentName.flattenToString())

        if (!isEnabled) {
            runOnUiThread { methodChannel?.invokeMethod("requestPermission", null) }
        }
    }

    private fun setupMediaSessionListener() {
        try {
            val component = ComponentName(this, NotificationListener::class.java)
            val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            if (enabledListeners != null && enabledListeners.contains(component.flattenToString())) {
                val activeSessions = mediaSessionManager.getActiveSessions(component)
                mediaSessionManager.addOnActiveSessionsChangedListener(sessionListener, component)
                if (activeSessions.isNotEmpty()) {
                    sessionListener.onActiveSessionsChanged(activeSessions)
                }
            }
        } catch (e: SecurityException) {
            Log.e("KemPlayer", "Permission not granted", e)
        }
    }

    private fun sendMediaInfoToFlutter() {
        methodChannel?.invokeMethod("mediaInfoUpdated", getCurrentMediaInfo())
    }

        private fun getCurrentMediaInfo(): Map<String, Any?> {
        val metadata = mediaController?.metadata
        val playbackState = mediaController?.playbackState
        
        val albumArt = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
        val albumArtUri = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
        val displayIconUri = metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_ICON_URI)
        val albumArtString = albumArt?.let { bitmapToBase64(it) }
        
        val duration = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        
        // Fix: Calculate the exact real-time position right now
        var currentPosition = playbackState?.position ?: 0L
        if (playbackState?.state == PlaybackState.STATE_PLAYING) {
            val timeDelta = android.os.SystemClock.elapsedRealtime() - (playbackState?.lastPositionUpdateTime ?: 0L)
            currentPosition += (timeDelta * (playbackState?.playbackSpeed ?: 1.0f)).toLong()
        }
        
        // Safety check
        if (currentPosition < 0) currentPosition = 0
        if (duration > 0 && currentPosition > duration) currentPosition = duration

        return mapOf(
            "title" to (metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Waiting for music..."),
            "artist" to (metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "KemPlayer"),
            "albumArtUri" to albumArtUri,
            "albumArt" to albumArtString,
            "displayIconUri" to displayIconUri,
            "isPlaying" to (playbackState?.state == PlaybackState.STATE_PLAYING),
            "packageName" to mediaController?.packageName,
            "duration" to duration,
            "position" to currentPosition, // Sending calculated real-time position
            "playbackSpeed" to (playbackState?.playbackSpeed ?: 1.0f)
        )
    }


    private fun handleMediaControl(command: String?) {
        val transportControls = mediaController?.transportControls
        when (command) {
            "play_pause" -> {
                if (mediaController?.playbackState?.state == PlaybackState.STATE_PLAYING) {
                    transportControls?.pause()
                } else {
                    transportControls?.play()
                }
            }
            "next" -> transportControls?.skipToNext()
            "previous" -> transportControls?.skipToPrevious()
        }
    }

    private fun bitmapToBase64(bitmap: Bitmap): String {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return Base64.encodeToString(stream.toByteArray(), Base64.DEFAULT)
    }
    
    override fun onResume() {
        super.onResume()
        setupMediaSessionListener()
        if (mediaController != null) sendMediaInfoToFlutter()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        mediaController?.unregisterCallback(mediaControllerCallback)
        try { mediaSessionManager.removeOnActiveSessionsChangedListener(sessionListener) } catch (e: Exception) {}
    }
}
