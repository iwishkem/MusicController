package kemplayer.iwishkem.com.tr

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Bundle
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
            Log.d("KemPlayer", "Metadata changed: ${metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)}")
            sendMediaInfoToFlutter()
        }

        override fun onPlaybackStateChanged(state: PlaybackState?) {
            Log.d("KemPlayer", "Playback state changed: ${state?.state}")
            sendMediaInfoToFlutter()
        }
    }

    private val sessionListener = object : MediaSessionManager.OnActiveSessionsChangedListener {
        override fun onActiveSessionsChanged(controllers: MutableList<MediaController>?) {
            Log.d("KemPlayer", "Active sessions changed: ${controllers?.size}")

            // Unregister previous controller callback
            mediaController?.unregisterCallback(mediaControllerCallback)

            // Get the first active controller (usually the music app)
            mediaController = controllers?.firstOrNull()

            // Register callback for the new controller
            mediaController?.registerCallback(mediaControllerCallback)

            // Send initial data to Flutter
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
                    result.success(getCurrentMediaInfo())
                }
                "mediaControl" -> {
                    val command = call.argument<String>("command")
                    handleMediaControl(command)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Request notification listener permission and set up listener
        setupMediaSessionListener()

        // Try to get existing active sessions immediately
        refreshActiveSession()
    }

    private fun setupMediaSessionListener() {
        try {
            val component = ComponentName(this, NotificationListener::class.java)
            val activeSessions = mediaSessionManager.getActiveSessions(component)

            // Set up the listener for future changes
            mediaSessionManager.addOnActiveSessionsChangedListener(sessionListener, component)

            Log.d("KemPlayer", "Media session listener set up. Active sessions: ${activeSessions.size}")

            // Handle existing sessions
            sessionListener.onActiveSessionsChanged(activeSessions)

        } catch (e: SecurityException) {
            Log.e("KemPlayer", "Permission not granted for notification access", e)
        }
    }

    private fun refreshActiveSession() {
        try {
            val component = ComponentName(this, NotificationListener::class.java)
            val activeSessions = mediaSessionManager.getActiveSessions(component)

            Log.d("KemPlayer", "Refreshing active session. Found: ${activeSessions.size}")

            if (activeSessions.isNotEmpty()) {
                mediaController?.unregisterCallback(mediaControllerCallback)
                mediaController = activeSessions.first()
                mediaController?.registerCallback(mediaControllerCallback)

                // Force send current info to Flutter
                sendMediaInfoToFlutter()
            }
        } catch (e: SecurityException) {
            Log.e("KemPlayer", "Permission not granted for notification access", e)
        }
    }

    private fun sendMediaInfoToFlutter() {
        val info = getCurrentMediaInfo()
        Log.d("KemPlayer", "Sending media info to Flutter: ${info["title"]}")
        methodChannel?.invokeMethod("mediaInfoUpdated", info)
    }

    private fun getCurrentMediaInfo(): Map<String, Any?> {
        val metadata = mediaController?.metadata
        val playbackState = mediaController?.playbackState
        val albumArt = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
        val albumArtUri = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
        val displayIconUri = metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_ICON_URI)

        val albumArtString = albumArt?.let { bitmapToBase64(it) }
        val isPlaying = playbackState?.state == PlaybackState.STATE_PLAYING

        return mapOf(
            "title" to (metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown"),
            "artist" to (metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "Unknown"),
            "albumArtUri" to albumArtUri,
            "albumArt" to albumArtString,
            "displayIconUri" to displayIconUri,
            "isPlaying" to isPlaying
        )
    }

    private fun handleMediaControl(command: String?) {
        val transportControls = mediaController?.transportControls
        when (command) {
            "play_pause" -> {
                val playbackState = mediaController?.playbackState
                if (playbackState?.state == PlaybackState.STATE_PLAYING) {
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
        val byteArrayOutputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)
        val byteArray = byteArrayOutputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.DEFAULT)
    }

    override fun onResume() {
        super.onResume()
        // Refresh session when app comes to foreground
        refreshActiveSession()
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaController?.unregisterCallback(mediaControllerCallback)
        try {
            val component = ComponentName(this, NotificationListener::class.java)
            mediaSessionManager.removeOnActiveSessionsChangedListener(sessionListener)
        } catch (e: Exception) {
            Log.e("KemPlayer", "Error removing session listener", e)
        }
    }
}