package com.example.mimusic.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.adapters.SongAdapter
import com.example.mimusic.datas.Song
import com.example.mimusic.services.MusicPlayer
import com.example.mimusic.services.MusicPlayer.playSong
import com.example.mimusic.services.UserManager
import com.example.mimusic.utils.Mp3MetadataExtractor

class LovedFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_loved, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val recyclerView = view.findViewById<RecyclerView>(R.id.lovedRecyclerView)
        recyclerView.layoutManager = LinearLayoutManager(requireContext())

        // Получаем список всех песен
        val allSongs = Mp3MetadataExtractor.getRawSongs(requireContext())

        // Фильтруем только лайкнутые песни
        val lovedSongs = allSongs.filter { song ->
            UserManager.currentUser?.likedSongs?.contains(song.filePath) ?: false
        }
        MusicPlayer.setSongList(lovedSongs)
        recyclerView.adapter = SongAdapter(lovedSongs) { song ->
            playSong(requireContext(), song)
        }
    }
}