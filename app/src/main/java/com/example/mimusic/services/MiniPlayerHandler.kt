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

    init {
        setupListeners()
        updatePlayerState()
        handler.post(updateProgress)

        // Устанавливаем слушатель изменения песни
        MusicPlayer.setOnSongChangedListener {
            updatePlayerState()
        }
    }

    private fun setupListeners() {
        playButton.setOnClickListener {
            if (MusicPlayer.isPlaying()) {
                MusicPlayer.pause()
            } else {
                MusicPlayer.resume()
            }
            updatePlayerState()
        }

        rootView.setOnClickListener {
            val currentSong = MusicPlayer.getCurrentSong()
            if (currentSong != null) {
                val bottomSheet = MusicBottomSheetFragment.newInstance(currentSong)
                bottomSheet.show((context as FragmentActivity).supportFragmentManager, bottomSheet.tag)
            }
        }
    }

    private fun updatePlayerState() {
        val currentSong = MusicPlayer.getCurrentSong()
        if (currentSong != null) {
            playerText.text = currentSong.title
            playerImage.setImageBitmap(currentSong.coverArt)
        }

        if (MusicPlayer.isPlaying()) {
            playButton.setIconResource(R.drawable.ic_pause)
        } else {
            playButton.setIconResource(R.drawable.ic_play)
        }
    }

    private fun updatePlayerProgress() {
        if (MusicPlayer.isPlaying()) {
            val duration = MusicPlayer.getDuration()
            if (duration > 0) {
                val progress = MusicPlayer.getCurrentPosition().toFloat() / duration
                val progressDrawable = playerBackground.background as LayerDrawable
                val clipDrawable = progressDrawable.findDrawableByLayerId(android.R.id.progress) as ClipDrawable
                clipDrawable.level = (progress * 10000).toInt()
            }
        }
    }

    fun release() {
        handler.removeCallbacks(updateProgress)
    }
}