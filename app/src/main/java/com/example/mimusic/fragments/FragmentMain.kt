package com.example.mimusic.fragments

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.adapters.SongAdapter
import com.example.mimusic.datas.Song
import com.example.mimusic.serverSide.ApiClient
import com.example.mimusic.services.MusicPlayer
import com.example.mimusic.utils.SongViewModel
import com.example.mimusic.utils.base64ToBitmap
import kotlinx.coroutines.launch

class FragmentMain : Fragment() {
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: SongAdapter
    private val viewModel: SongViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val view = inflater.inflate(R.layout.fragment_main, container, false)
        recyclerView = view.findViewById(R.id.my_recycler_view)
        recyclerView.layoutManager = LinearLayoutManager(requireContext())

        adapter = SongAdapter(emptyList()) { song ->
            playSong(song)
        }
        recyclerView.adapter = adapter

        return view
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        viewModel.songs.observe(viewLifecycleOwner) { songs ->
            adapter.updateSongs(songs)
        }

        viewModel.loadSongs()
    }

    private fun playSong(song: Song) {
        viewModel.songs.value?.let { songs ->
            MusicPlayer.setSongList(songs)
        }

        MusicPlayer.playSong(requireContext(), song)
        val bottomSheetFragment = MusicBottomSheetFragment.newInstance(song)
        bottomSheetFragment.show(parentFragmentManager, bottomSheetFragment.tag)
    }
}