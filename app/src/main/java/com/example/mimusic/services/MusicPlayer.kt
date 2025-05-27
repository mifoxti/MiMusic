package com.example.mimusic.services

import android.content.Context
import android.media.MediaPlayer
import android.util.Log
import com.example.mimusic.datas.Song

object MusicPlayer {
    private var mediaPlayer: MediaPlayer? = null
    private var currentSong: Song? = null
    private var isPrepared = false
    private var onSongChangedListener: (() -> Unit)? = null
    private var onPlaybackStartedListener: (() -> Unit)? = null // Новый слушатель

    fun setOnSongChangedListener(listener: () -> Unit) {
        onSongChangedListener = listener
    }

    fun setOnPlaybackStartedListener(listener: () -> Unit) {
        onPlaybackStartedListener = listener
    }

    fun playSong(context: Context, song: Song, onPrepared: (() -> Unit)? = null) {
        if (mediaPlayer == null) {
            mediaPlayer = MediaPlayer()
        } else {
            mediaPlayer?.reset()
        }

        try {
            val resourceId = context.resources.getIdentifier(song.title.replace(" ", "_"), "raw", context.packageName)
            if (resourceId == 0) {
                Log.e("MusicPlayer", "Resource not found for song: ${song.title}")
                return
            }

            val assetFileDescriptor = context.resources.openRawResourceFd(resourceId)
            mediaPlayer?.apply {
                setDataSource(assetFileDescriptor.fileDescriptor, assetFileDescriptor.startOffset, assetFileDescriptor.length)
                assetFileDescriptor.close()

                setOnPreparedListener {
                    isPrepared = true
                    start()
                    currentSong = song
                    Log.d("MusicPlayer", "Song started: ${song.title}, duration: ${duration}")
                    onPrepared?.invoke()
                    onSongChangedListener?.invoke()
                    onPlaybackStartedListener?.invoke() // Уведомляем о начале воспроизведения
                }

                setOnCompletionListener {
                    Log.d("MusicPlayer", "Song completed: ${song.title}")
                    currentSong = null
                    isPrepared = false
                    onSongChangedListener?.invoke()
                }

                setOnErrorListener { _, what, extra ->
                    Log.e("MusicPlayer", "MediaPlayer error: what=$what, extra=$extra")
                    false
                }

                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e("MusicPlayer", "Error initializing MediaPlayer for song: ${song.title}", e)
        }
    }

    fun seekTo(position: Int) {
        if (mediaPlayer != null && position in 0..(mediaPlayer!!.duration)) {
            mediaPlayer?.seekTo(position)
            Log.d("MusicPlayer", "Seek to: $position")
        }
    }

    fun pause() {
        if (mediaPlayer?.isPlaying == true) {
            mediaPlayer?.pause()
            Log.d("MusicPlayer", "Song paused")
        }
    }

    fun resume() {
        if (mediaPlayer != null && !mediaPlayer!!.isPlaying && isPrepared) {
            mediaPlayer?.start()
            Log.d("MusicPlayer", "Song resumed")
        }
    }

    fun isPlaying(): Boolean {
        return mediaPlayer?.isPlaying ?: false
    }

    fun getCurrentPosition(): Int {
        return mediaPlayer?.currentPosition ?: 0
    }

    fun getDuration(): Int {
        return mediaPlayer?.duration ?: 0
    }

    fun release() {
        mediaPlayer?.release()
        mediaPlayer = null
        currentSong = null
        isPrepared = false
        Log.d("MusicPlayer", "MediaPlayer released")
    }

    fun getCurrentSong(): Song? {
        return currentSong
    }

    fun isPrepared(): Boolean {
        return isPrepared
    }
}