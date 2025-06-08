package com.example.mimusic.services

import android.content.Context
import android.media.MediaPlayer
import android.util.Log
import com.example.mimusic.datas.Song

object MusicPlayer {
    private var mediaPlayer: MediaPlayer? = null
    private var currentSong: Song? = null
    private var isPrepared = false
    private val songChangedListeners = mutableListOf<() -> Unit>()
    private val playbackStateListeners = mutableListOf<() -> Unit>()
    private var songList: List<Song> = emptyList()
    private var currentPosition = -1

    fun setSongList(list: List<Song>) {
        songList = list
        if (songList.isNotEmpty() && currentPosition == -1) {
            currentPosition = 0
        }
    }

    fun addSongChangedListener(listener: () -> Unit) {
        songChangedListeners.add(listener)
    }

    fun removeSongChangedListener(listener: () -> Unit) {
        songChangedListeners.remove(listener)
    }

    fun addPlaybackStateListener(listener: () -> Unit) {
        playbackStateListeners.add(listener)
    }

    fun removePlaybackStateListener(listener: () -> Unit) {
        playbackStateListeners.remove(listener)
    }

    fun playSong(context: Context, song: Song, onPrepared: (() -> Unit)? = null) {
        currentPosition = songList.indexOfFirst { it.fileName == song.fileName }
            .takeIf { it != -1 } ?: run {
            Log.e("MusicPlayer", "Song not found in list: ${song.fileName}")
            return
        }

        mediaPlayer?.release()
        mediaPlayer = MediaPlayer().apply {
            try {
                val resourceId = context.resources.getIdentifier(
                    song.fileName,
                    "raw",
                    context.packageName
                )

                if (resourceId == 0) {
                    Log.e("MusicPlayer", "Resource not found for file: ${song.fileName}")
                    return@apply
                }

                val assetFileDescriptor = context.resources.openRawResourceFd(resourceId)
                setDataSource(
                    assetFileDescriptor.fileDescriptor,
                    assetFileDescriptor.startOffset,
                    assetFileDescriptor.length
                )
                assetFileDescriptor.close()

                setOnPreparedListener {
                    isPrepared = true
                    start()
                    currentSong = song
                    Log.d("MusicPlayer", "Song started: ${song.title}")
                    onPrepared?.invoke()
                    notifySongChanged()
                    notifyPlaybackStateChanged()
                }

                setOnCompletionListener {
                    Log.d("MusicPlayer", "Song completed: ${song.title}")
                    notifyPlaybackStateChanged()
                    playNext(context)
                }

                setOnErrorListener { _, what, extra ->
                    Log.e("MusicPlayer", "MediaPlayer error: what=$what, extra=$extra")
                    false
                }

                prepareAsync()
            } catch (e: Exception) {
                Log.e("MusicPlayer", "Error initializing MediaPlayer", e)
                release()
            }
        }
    }

    fun playNext(context: Context) {
        if (songList.isEmpty()) {
            Log.e("MusicPlayer", "Song list is empty!")
            return
        }
        if (currentPosition == -1) {
            Log.e("MusicPlayer", "No current position set!")
            return
        }

        val nextPosition = (currentPosition + 1) % songList.size
        Log.d("MusicPlayer", "Playing next song at position: $nextPosition")
        playSong(context, songList[nextPosition])
    }

    fun playPrevious(context: Context) {
        if (songList.isEmpty()) {
            Log.e("MusicPlayer", "Song list is empty!")
            return
        }
        if (currentPosition == -1) {
            Log.e("MusicPlayer", "No current position set!")
            return
        }

        val prevPosition = if (currentPosition - 1 < 0) songList.size - 1 else currentPosition - 1
        Log.d("MusicPlayer", "Playing previous song at position: $prevPosition")
        playSong(context, songList[prevPosition])
    }

    fun seekTo(position: Int) {
        if (isPrepared && position in 0..getDuration()) {
            mediaPlayer?.seekTo(position)
        }
    }

    fun pause() {
        if (isPlaying()) {
            mediaPlayer?.pause()
            notifyPlaybackStateChanged()
        }
    }

    fun resume() {
        if (isPrepared && !isPlaying()) {
            mediaPlayer?.start()
            notifyPlaybackStateChanged()
        }
    }

    fun isPlaying(): Boolean = mediaPlayer?.isPlaying ?: false

    fun getCurrentPosition(): Int = mediaPlayer?.currentPosition ?: 0

    fun getDuration(): Int = mediaPlayer?.duration ?: 0

    fun release() {
        mediaPlayer?.release()
        mediaPlayer = null
        currentSong = null
        isPrepared = false
        currentPosition = -1
        songChangedListeners.clear()
        playbackStateListeners.clear()
    }

    fun getCurrentSong(): Song? = currentSong

    fun isPrepared(): Boolean = isPrepared

    private fun notifySongChanged() {
        songChangedListeners.forEach { it.invoke() }
    }

    private fun notifyPlaybackStateChanged() {
        playbackStateListeners.forEach { it.invoke() }
    }
}