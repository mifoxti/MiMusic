package com.example.mimusic.services

import android.content.Context
import android.media.MediaPlayer
import android.util.Log
import com.example.mimusic.datas.Song
import com.example.mimusic.serverSide.ApiClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import okhttp3.ResponseBody
import java.io.File
import java.io.FileOutputStream

object MusicPlayer {
    private var mediaPlayer: MediaPlayer? = null
    private var currentSong: Song? = null
    private var tempFile: File? = null
    private var isPrepared = false
    private var currentPosition = -1
    private var songList: List<Song> = emptyList()

    private val songChangedListeners = mutableListOf<() -> Unit>()
    private val playbackStateListeners = mutableListOf<() -> Unit>()
    private val progressUpdateListeners = mutableListOf<(Int, Int) -> Unit>()

    private val playerScope = CoroutineScope(Dispatchers.IO)
    private var progressUpdateJob: Job? = null

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

    fun addProgressUpdateListener(listener: (Int, Int) -> Unit) {
        progressUpdateListeners.add(listener)
    }

    fun removeProgressUpdateListener(listener: (Int, Int) -> Unit) {
        progressUpdateListeners.remove(listener)
    }

    fun playSong(context: Context, song: Song, onPrepared: (() -> Unit)? = null) {
        currentPosition = songList.indexOfFirst { it.idOnServer == song.idOnServer }
            .takeIf { it != -1 } ?: run {
            Log.e("MusicPlayer", "Song not found in list: ${song.title}")
            return
        }

        playerScope.launch {
            try {
                val response = ApiClient.apiService.streamTrack(song.idOnServer ?: return@launch)
                if (response.isSuccessful) {
                    response.body()?.let { body ->
                        tempFile = createTempFile(context, "music_${song.idOnServer}", ".mp3")
                        tempFile?.let { file ->
                            saveResponseToFile(body, file)
                            launch(Dispatchers.Main) {
                                playFile(context, file, song, onPrepared)
                            }
                        }
                    }
                } else {
                    Log.e("MusicPlayer", "Server error: ${response.code()}")
                }
            } catch (e: Exception) {
                Log.e("MusicPlayer", "Streaming error", e)
            }
        }
    }

    fun playNext(context: Context, onPrepared: (() -> Unit)? = null) {
        if (songList.isEmpty()) return

        currentPosition = (currentPosition + 1) % songList.size
        playSong(context, songList[currentPosition], onPrepared)
    }

    fun playPrevious(context: Context, onPrepared: (() -> Unit)? = null) {
        if (songList.isEmpty()) return

        currentPosition = if (currentPosition - 1 < 0) songList.size - 1 else currentPosition - 1
        playSong(context, songList[currentPosition], onPrepared)
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
            startProgressUpdates()
        }
    }

    fun seekTo(position: Int) {
        if (isPrepared && position in 0..getDuration()) {
            mediaPlayer?.seekTo(position)
        }
    }

    fun isPlaying(): Boolean = mediaPlayer?.isPlaying ?: false

    fun getCurrentPosition(): Int = mediaPlayer?.currentPosition ?: 0

    fun getDuration(): Int = mediaPlayer?.duration ?: 0

    fun getCurrentSong(): Song? = currentSong

    fun isPrepared(): Boolean = isPrepared

    fun release() {
        mediaPlayer?.release()
        tempFile?.delete()
        mediaPlayer = null
        currentSong = null
        isPrepared = false
        currentPosition = -1
        progressUpdateJob?.cancel()
        songChangedListeners.clear()
        playbackStateListeners.clear()
        progressUpdateListeners.clear()
    }

    private fun createTempFile(context: Context, prefix: String, suffix: String): File {
        return File(context.cacheDir, "$prefix$suffix").apply {
            createNewFile()
        }
    }

    private fun saveResponseToFile(body: ResponseBody, file: File) {
        FileOutputStream(file).use { output ->
            body.byteStream().use { input ->
                input.copyTo(output)
            }
        }
    }

    private fun playFile(context: Context, file: File, song: Song, onPrepared: (() -> Unit)?) {
        if (mediaPlayer == null) {
            mediaPlayer = MediaPlayer()
        } else {
            mediaPlayer?.reset() // Сброс перед новой загрузкой
        }

        try {
            mediaPlayer?.setDataSource(file.path)
            mediaPlayer?.setOnPreparedListener {
                isPrepared = true
                mediaPlayer?.start()
                currentSong = song
                onPrepared?.invoke()
                notifySongChanged()
                notifyPlaybackStateChanged()
                startProgressUpdates()
            }
            mediaPlayer?.setOnCompletionListener {
                notifyPlaybackStateChanged()
                playNext(context)
            }
            mediaPlayer?.setOnErrorListener { _, what, extra ->
                Log.e("MusicPlayer", "Playback error: what=$what, extra=$extra")
                false
            }
            mediaPlayer?.prepareAsync()
        } catch (e: Exception) {
            Log.e("MusicPlayer", "Error setting data source", e)
        }
    }


    private fun startProgressUpdates() {
        progressUpdateJob?.cancel()
        progressUpdateJob = playerScope.launch {
            while (isPrepared && mediaPlayer?.isPlaying == true) {
                val pos = getCurrentPosition()
                val dur = getDuration()
                progressUpdateListeners.forEach { it.invoke(pos, dur) }
                kotlinx.coroutines.delay(1000)
            }
        }
    }

    private fun notifySongChanged() {
        songChangedListeners.forEach { it.invoke() }
    }

    private fun notifyPlaybackStateChanged() {
        playbackStateListeners.forEach { it.invoke() }
    }
}