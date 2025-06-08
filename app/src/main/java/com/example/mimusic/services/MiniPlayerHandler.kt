package com.example.mimusic.services

import android.content.Context
import android.graphics.drawable.ClipDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.TextView
import androidx.fragment.app.FragmentActivity
import com.example.mimusic.fragments.MusicBottomSheetFragment
import com.example.mimusic.R
import com.google.android.material.button.MaterialButton
import com.google.android.material.imageview.ShapeableImageView

class MiniPlayerHandler(
    private val context: Context,
    private val rootView: View
) {
    private val playerImage: ShapeableImageView = rootView.findViewById(R.id.playerImage)
    private val playerText: TextView = rootView.findViewById(R.id.playerText)
    private val playButton: MaterialButton = rootView.findViewById(R.id.playButton)
    private val playerBackground: View = rootView.findViewById(R.id.playerBackground)

    private val handler = Handler(Looper.getMainLooper())
    private val updateProgress = object : Runnable {
        override fun run() {
            updatePlayerProgress()
            handler.postDelayed(this, 1000)
        }
    }

    private val songChangedListener: () -> Unit = {
        handler.post {
            updatePlayerState()
            updatePlayerProgress()
        }
    }

    private val playbackStateListener: () -> Unit = {
        handler.post {
            updatePlayButtonState()
            updatePlayerProgress()
        }
    }

    init {
        setupListeners()
        MusicPlayer.addSongChangedListener(songChangedListener)
        MusicPlayer.addPlaybackStateListener(playbackStateListener)
        updatePlayerState()
        handler.post(updateProgress)
    }

    private fun registerMusicPlayerListeners() {
        MusicPlayer.addSongChangedListener(songChangedListener)
        MusicPlayer.addPlaybackStateListener(playbackStateListener)
    }

    private fun unregisterMusicPlayerListeners() {
        MusicPlayer.removeSongChangedListener(songChangedListener)
        MusicPlayer.removePlaybackStateListener(playbackStateListener)
    }

    private fun setupListeners() {
        playButton.setOnClickListener {
            if (MusicPlayer.isPlaying()) {
                MusicPlayer.pause()
            } else {
                MusicPlayer.resume()
            }
        }

        rootView.setOnClickListener {
            MusicPlayer.getCurrentSong()?.let { currentSong ->
                val bottomSheet = MusicBottomSheetFragment.newInstance(currentSong)
                bottomSheet.show((context as FragmentActivity).supportFragmentManager, bottomSheet.tag)
            }
        }
    }

    private fun updatePlayerState() {
        MusicPlayer.getCurrentSong()?.let { currentSong ->
            playerText.text = currentSong.title
            playerImage.setImageBitmap(currentSong.coverArt)
            updatePlayButtonState()
        } ?: run {
            playerText.text = context.getString(R.string.no_song_playing)
            playerImage.setImageResource(R.drawable.music_image)
            playButton.setIconResource(R.drawable.ic_play)
        }
    }

    private fun updatePlayButtonState() {
        playButton.setIconResource(
            if (MusicPlayer.isPlaying()) R.drawable.ic_pause else R.drawable.ic_play
        )
    }

    private fun updatePlayerProgress() {
        if (MusicPlayer.isPrepared()) {
            val duration = MusicPlayer.getDuration()
            if (duration > 0) {
                val progress = MusicPlayer.getCurrentPosition().toFloat() / duration
                val progressDrawable = playerBackground.background as? LayerDrawable
                progressDrawable?.let {
                    val clipDrawable = it.findDrawableByLayerId(android.R.id.progress) as? ClipDrawable
                    clipDrawable?.level = (progress * 10000).toInt()
                }
            }
        }
    }

    fun release() {
        handler.removeCallbacks(updateProgress)
        MusicPlayer.removeSongChangedListener(songChangedListener)
        MusicPlayer.removePlaybackStateListener(playbackStateListener)
    }
}