package com.example.kemplayer

import android.content.ComponentName
import android.graphics.Bitmap
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.os.Bundle
import android.util.Base64
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "kemplayer/media"
    private var mediaSessionManager: MediaSessionManager? = null
    private var mediaController: MediaController? = null
    private var listener: MediaSessionManager.OnActiveSessionsChangedListener? = null
    private var currentPackage: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaSessionManager = getSystemService(MediaSessionManager::class.java)
        val componentName = ComponentName(this, NotificationListener::class.java)

        listener = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
            android.util.Log.d("MediaSession", "Active sessions changed: ${controllers?.size} controllers")
            if (controllers != null && controllers.isNotEmpty()) {
                // Find the controller with the most recent metadata
                var bestController: MediaController? = null
                for (controller in controllers) {
                    val metadata = controller.metadata
                    if (metadata != null) {
                        val title = metadata.getString(android.media.MediaMetadata.METADATA_KEY_TITLE)
                        if (!title.isNullOrEmpty()) {
                            bestController = controller
                            break
                        }
                    }
                }
                
                if (bestController != null) {
                    mediaController = bestController
                    currentPackage = mediaController?.packageName
                    android.util.Log.d("MediaSession", "Selected controller from package: $currentPackage")
                    setUpCallback()
                    sendMediaInfoToFlutter(flutterEngine)
                } else if (controllers.isNotEmpty()) {
                    // Fallback to first controller
                    mediaController = controllers[0]
                    currentPackage = mediaController?.packageName
                    android.util.Log.d("MediaSession", "Fallback to first controller from package: $currentPackage")
                    setUpCallback()
                    sendMediaInfoToFlutter(flutterEngine)
                }
            }
        }
        mediaSessionManager?.addOnActiveSessionsChangedListener(listener!!, componentName)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMediaInfo" -> {
                    val info = getCurrentMediaInfo()
                    result.success(info)
                }
                "mediaControl" -> {
                    val command = call.argument<String>("command")
                    command?.let { controlMedia(it) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setUpCallback() {
        mediaController?.registerCallback(object : MediaController.Callback() {
            override fun onMetadataChanged(metadata: android.media.MediaMetadata?) {
                sendMediaInfoToFlutter(flutterEngine!!)
            }

            override fun onPlaybackStateChanged(state: android.media.session.PlaybackState?) {
                sendMediaInfoToFlutter(flutterEngine!!)
            }
        })
    }

    private fun getCurrentMediaInfo(): Map<String, Any?> {
        val metadata = mediaController?.metadata
        val albumArt = metadata?.getBitmap(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART)
        val albumArtUri = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
        val displayIconUri = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_DISPLAY_ICON_URI)
        
        // Debug logging
        android.util.Log.d("MediaInfo", "Album art bitmap: ${albumArt != null}")
        android.util.Log.d("MediaInfo", "Album art URI: $albumArtUri")
        android.util.Log.d("MediaInfo", "Display icon URI: $displayIconUri")
        android.util.Log.d("MediaInfo", "Title: ${metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE)}")
        
        val albumArtString = albumArt?.let { bitmapToBase64(it) }
        
        return mapOf(
            "title" to metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE),
            "artist" to metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST),
            "albumArtUri" to albumArtUri,
            "albumArt" to albumArtString,
            "displayIconUri" to displayIconUri
        )
    }

    private fun bitmapToBase64(bitmap: Bitmap): String {
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        val byteArray = outputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.DEFAULT)
    }

    private fun controlMedia(command: String) {
        val controls = mediaController?.transportControls ?: return
        when (command) {
            "play_pause" -> {
                val state = mediaController?.playbackState?.state
                if (state == android.media.session.PlaybackState.STATE_PLAYING) {
                    controls.pause()
                } else {
                    controls.play()
                }
            }
            "next" -> controls.skipToNext()
            "previous" -> controls.skipToPrevious()
        }
    }

    private fun sendMediaInfoToFlutter(flutterEngine: FlutterEngine) {
        val mediaInfo = getCurrentMediaInfo()
        runOnUiThread {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("mediaInfoUpdated", mediaInfo)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaSessionManager?.removeOnActiveSessionsChangedListener(listener!!)
    }
}
