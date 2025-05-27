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
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.adapters.SongAdapter
import com.example.mimusic.datas.Song
import com.example.mimusic.services.MusicPlayer

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

        // Создаем список песен
        val songs = getRawSongs(requireContext())

        // Передаем список в адаптер
        adapter = SongAdapter(songs) { song ->
            // Обработка клика по песне
            playSong(song)
        }
        recyclerView.adapter = adapter

        return view
    }

    private fun playSong(song: Song) {
        MusicPlayer.playSong(requireContext(), song)

        // Открываем Bottom Sheet с информацией о песне
        val bottomSheetFragment = MusicBottomSheetFragment.newInstance(song)
        bottomSheetFragment.show(parentFragmentManager, bottomSheetFragment.tag)
    }

    fun extractCoverArt(context: Context, resourceId: Int): Bitmap? {
        val retriever = MediaMetadataRetriever()
        val fileDescriptor = context.resources.openRawResourceFd(resourceId)
        retriever.setDataSource(
            fileDescriptor.fileDescriptor,
            fileDescriptor.startOffset,
            fileDescriptor.length
        )
        fileDescriptor.close()

        val coverByteArray = retriever.embeddedPicture
        retriever.release()

        return if (coverByteArray != null) {
            BitmapFactory.decodeByteArray(coverByteArray, 0, coverByteArray.size)
        } else {
            null
        }
    }

    fun getRawSongs(context: Context): List<Song> {
        val songs = mutableListOf<Song>()
        val resources = context.resources
        val packageName = context.packageName

        // Получаем список всех файлов в папке res/raw
        val field = R.raw::class.java
        val rawFiles = field.declaredFields

        for (file in rawFiles) {
            val resourceId = resources.getIdentifier(file.name, "raw", packageName)
            if (resourceId != 0) {
                val songName = file.name.replace("_", " ") // Убираем подчеркивания
                val filePath = "android.resource://$packageName/$resourceId"
                val coverArt = extractCoverArt(context, resourceId)
                songs.add(Song(songName, filePath, coverArt))
                Log.d("FragmentMain", "Found song: $songName, path: $filePath")
            } else {
                Log.d("FragmentMain", "Resource ID is 0 for file: ${file.name}")
            }
        }

        if (songs.isEmpty()) {
            Log.d("FragmentMain", "No files found in res/raw")
        }

        return songs
    }
}