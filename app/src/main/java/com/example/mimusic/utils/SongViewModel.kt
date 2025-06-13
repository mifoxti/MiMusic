package com.example.mimusic.utils

import android.util.Log
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.mimusic.datas.Song
import com.example.mimusic.serverSide.ApiClient
import kotlinx.coroutines.launch

class SongViewModel : ViewModel() {
    private val apiService = ApiClient.apiService
    private val _songs = MutableLiveData<List<Song>>()
    val songs: LiveData<List<Song>> = _songs

    fun loadSongs() {
        viewModelScope.launch {
            try {
                val response = apiService.getAllTracks()
                if (response.isSuccessful) {
                    val serverSongs = response.body() ?: emptyList()
                    val songList = serverSongs.map { serverSong ->
                        Song(
                            title = serverSong.title,
                            idOnServer = serverSong.id,
                            artist = serverSong.artist ?: "Unknown",
                            coverArt = serverSong.cover?.base64ToBitmap()
                        )
                    }
                    _songs.value = songList
                }
            } catch (e: Exception) {
                Log.e("SongViewModel", "Error loading songs", e)
            }
        }
    }
}