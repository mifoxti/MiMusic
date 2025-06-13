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

//        val lovedSongs = listOf(
//            Song("Tramontane", , "Artist 1"),
//            Song("Favorite Song", ", "Artist 2"),
//            Song("Best Track", "path3", "Artist 3")
//        )

//        recyclerView.adapter = SongAdapter(lovedSongs) { song ->
//            // Обработка клика по песне
//            // Например, воспроизведение
//        }
    }
}