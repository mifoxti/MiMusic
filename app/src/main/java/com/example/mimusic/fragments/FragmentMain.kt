package com.example.mimusic.fragments

import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.adapters.SongAdapter
import com.example.mimusic.datas.Song
import com.example.mimusic.serverSide.ApiClient
import com.example.mimusic.serverSide.ToggleLikeRequest
import com.example.mimusic.services.MusicPlayer
import com.example.mimusic.utils.base64ToBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class FragmentMain : Fragment() {
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: SongAdapter
    private var songs: List<Song> = emptyList()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val view = inflater.inflate(R.layout.fragment_main, container, false)
        recyclerView = view.findViewById(R.id.my_recycler_view)
        recyclerView.layoutManager = LinearLayoutManager(requireContext())

        adapter = SongAdapter(emptyList(), ::playSong, ::toggleLikeForSong)
        recyclerView.adapter = adapter

        return view
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        loadSongsFromServer()
    }

    private fun loadSongsFromServer() {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val response = ApiClient.apiService.getAllTracks()
                if (response.isSuccessful) {
                    val serverSongs = response.body() ?: emptyList()
                    songs = serverSongs.map { serverSong ->
                        Song(
                            title = serverSong.title,
                            idOnServer = serverSong.id,
                            artist = serverSong.artist ?: "Unknown",
                            coverArt = serverSong.cover?.base64ToBitmap()
                        )
                    }

                    withContext(Dispatchers.Main) {
                        adapter.updateSongs(songs)
                        loadLikesForSongs()
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(requireContext(), "Ошибка загрузки песен: ${response.code()}", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    Toast.makeText(requireContext(), "Ошибка подключения к серверу", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun loadLikesForSongs() {
        val userId = requireContext()
            .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)
        if (userId == -1) return

        songs.forEachIndexed { index, song ->
            lifecycleScope.launch(Dispatchers.IO) {
                try {
                    val response = ApiClient.apiService.isTrackLiked(song.idOnServer, userId)
                    if (response.isSuccessful) {
                        val liked = response.body()?.status ?: false
                        withContext(Dispatchers.Main) {
                            adapter.setLikeStateAt(index, liked)
                        }
                    }
                } catch (e: Exception) {
                    Log.e("FragmentMain", "Ошибка проверки лайка: ${e.message}")
                }
            }
        }
    }

    private fun toggleLikeForSong(song: Song, position: Int) {
        val userId = requireContext()
            .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)
        if (userId == -1) {
            Toast.makeText(requireContext(), "Пользователь не авторизован", Toast.LENGTH_SHORT).show()
            return
        }

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val response = ApiClient.apiService.toggleLike(song.idOnServer, ToggleLikeRequest(userId))
                if (response.isSuccessful) {
                    val liked = response.body()?.status ?: false
                    withContext(Dispatchers.Main) {
                        adapter.setLikeStateAt(position, liked)
                        Toast.makeText(
                            requireContext(),
                            if (liked) "Добавлено в избранное" else "Удалено из избранного",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(requireContext(), "Ошибка: ${response.code()}", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    Toast.makeText(requireContext(), "Сервер не отвечает", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun playSong(song: Song) {
        MusicPlayer.setSongList(songs)
        MusicPlayer.playSong(requireContext(), song)
        val bottomSheetFragment = MusicBottomSheetFragment.newInstance(song)
        bottomSheetFragment.show(parentFragmentManager, bottomSheetFragment.tag)
    }
}

