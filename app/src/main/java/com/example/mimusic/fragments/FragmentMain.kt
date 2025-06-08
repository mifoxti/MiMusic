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
import com.example.mimusic.utils.Mp3MetadataExtractor

class FragmentMain : Fragment() {
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: SongAdapter

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_main, container, false)

        recyclerView = view.findViewById(R.id.my_recycler_view)
        recyclerView.layoutManager = LinearLayoutManager(requireContext())

        val songs = Mp3MetadataExtractor.getRawSongs(requireContext())

        adapter = SongAdapter(songs) { song ->
            playSong(song)
        }
        recyclerView.adapter = adapter

        return view
    }

    private fun playSong(song: Song) {
        MusicPlayer.playSong(requireContext(), song)
        val bottomSheetFragment = MusicBottomSheetFragment.newInstance(song)
        bottomSheetFragment.show(parentFragmentManager, bottomSheetFragment.tag)
    }
}