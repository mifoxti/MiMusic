package com.example.mimusic.services

import android.content.Context
import android.graphics.drawable.ClipDrawable
import android.graphics.drawable.LayerDrawable
import android.view.View
import android.widget.TextView
import androidx.fragment.app.FragmentActivity
import com.example.mimusic.R
import com.example.mimusic.fragments.MusicBottomSheetFragment
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

    // Храним слушатели для удаления
    private val songChangedListener = {
        updatePlayerState()
        rootView.visibility = View.VISIBLE
    }

    private val playbackStateListener = {
        updatePlayerState()
    }

    private val progressUpdateListener = { currentPos: Int, duration: Int ->
        updateProgress(currentPos, duration)
    }

    init {
        setupListeners()
        updatePlayerState()

        // Подписка на обновления плеера
        MusicPlayer.apply {
            addSongChangedListener(songChangedListener)
            addPlaybackStateListener(playbackStateListener)
            addProgressUpdateListener(progressUpdateListener)
        }

        // Показываем миниплеер, если песня уже есть
        rootView.visibility = if (MusicPlayer.getCurrentSong() != null) View.VISIBLE else View.GONE
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
            MusicPlayer.getCurrentSong()?.let { song ->
                MusicBottomSheetFragment.newInstance(song).show(
                    (context as FragmentActivity).supportFragmentManager,
                    "bottom_sheet"
                )
            }
        }
    }

    private fun updatePlayerState() {
        MusicPlayer.getCurrentSong()?.let { song ->
            playerText.text = song.title
            song.coverArt?.let { playerImage.setImageBitmap(it) }
        }

        // Обновление иконки кнопки
        playButton.setIconResource(
            if (MusicPlayer.isPlaying()) R.drawable.ic_pause else R.drawable.ic_play
        )
    }

    private fun updateProgress(currentPos: Int, duration: Int) {
        if (duration > 0) {
            val progress = currentPos.toFloat() / duration
            (playerBackground.background as? LayerDrawable)?.let { layerDrawable ->
                (layerDrawable.findDrawableByLayerId(android.R.id.progress) as? ClipDrawable)?.let { clip ->
                    clip.level = (progress * 10000).toInt()
                }
            }
        }
    }

    fun release() {
        MusicPlayer.apply {
            removeSongChangedListener(songChangedListener)
            removePlaybackStateListener(playbackStateListener)
            removeProgressUpdateListener(progressUpdateListener)
        }
    }
}
