package com.example.kemplayer

import android.content.ComponentName
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "kemplayer/media"
    private var mediaSessionManager: MediaSessionManager? = null
    private var mediaController: MediaController? = null
    private var listener: MediaSessionManager.OnActiveSessionsChangedListener? = null
    private var currentPackage: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        mediaSessionManager = getSystemService(MediaSessionManager::class.java)

        val componentName = ComponentName(this, NotificationListener::class.java)

        listener = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
            if (controllers.isNotEmpty()) {
                mediaController = controllers[0]
                currentPackage = mediaController?.packageName
                setUpCallback()
                sendMediaInfoToFlutter()
            }
        }
        mediaSessionManager?.addOnActiveSessionsChangedListener(listener!!, componentName)

        MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                sendMediaInfoToFlutter()
            }

            override fun onPlaybackStateChanged(state: android.media.session.PlaybackState?) {
                sendMediaInfoToFlutter()
            }
        })
    }

    private fun getCurrentMediaInfo(): Map<String, Any?> {
        val metadata = mediaController?.metadata
        return mapOf(
            "title" to metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE),
            "artist" to metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST),
            "albumArtUri" to metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
        )
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

    private fun sendMediaInfoToFlutter() {
        val mediaInfo = getCurrentMediaInfo()
        runOnUiThread {
            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, CHANNEL).invokeMethod("mediaInfoUpdated", mediaInfo)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaSessionManager?.removeOnActiveSessionsChangedListener(listener!!)
    }
}
