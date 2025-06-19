package com.example.mimusic.fragments

import android.content.Context
import android.os.Bundle
import android.view.*
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.adapters.LovedAdapter
import com.example.mimusic.datas.Song
import com.example.mimusic.serverSide.ApiClient
import com.example.mimusic.serverSide.LovedRemote
import com.example.mimusic.serverSide.ToggleLikeRequest
import com.example.mimusic.services.MusicPlayer
import kotlinx.coroutines.launch

class LovedFragment : Fragment() {
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: LovedAdapter
    private var likedSongs: List<LovedRemote> = emptyList()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        return inflater.inflate(R.layout.fragment_loved, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        recyclerView = view.findViewById(R.id.lovedRecyclerView)
        recyclerView.layoutManager = LinearLayoutManager(requireContext())

        adapter = LovedAdapter(
            songs = likedSongs,
            onItemClick = { song -> playSong(song) },
            onLikeClick = { song, position -> toggleLike(song, position) }
        )

        recyclerView.adapter = adapter
        fetchLovedSongs()
    }

    private fun fetchLovedSongs() {
        val userId = requireContext().getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)

        if (userId == -1) return

        lifecycleScope.launch {
            try {
                val response = ApiClient.apiService.getLikedTracks(userId)
                if (response.isSuccessful) {
                    likedSongs = response.body() ?: emptyList()
                    adapter.updateData(likedSongs)
                } else {
                    Toast.makeText(requireContext(), "Ошибка загрузки любимых песен", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(requireContext(), "Сетевая ошибка", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun toggleLike(song: LovedRemote, position: Int) {
        val userId = requireContext().getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)

        lifecycleScope.launch {
            try {
                val response = ApiClient.apiService.toggleLike(song.id, ToggleLikeRequest(userId))
                if (response.isSuccessful) {
                    val updated = response.body()?.status == true
                    likedSongs = likedSongs.toMutableList().apply {
                        if (!updated) removeAt(position)
                    }
                    adapter.updateData(likedSongs)
                }
            } catch (e: Exception) {
                Toast.makeText(requireContext(), "Ошибка обновления лайка", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun playSong(song: LovedRemote) {
        val convertedList = likedSongs.map {
            Song(
                idOnServer = it.id,
                title = it.title,
                artist = it.artist ?: "",
                coverArt = it.coverArt?.let { base64 ->
                    val bytes = android.util.Base64.decode(base64, android.util.Base64.DEFAULT)
                    android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                }
            )
        }
        val selected = convertedList.find { it.idOnServer == song.id }
        if (selected != null) {
            MusicPlayer.setSongList(convertedList)
            MusicPlayer.playSong(requireContext(), selected)
            val sheet = MusicBottomSheetFragment.newInstance(selected)
            sheet.show(parentFragmentManager, sheet.tag)
        }
    }
}
