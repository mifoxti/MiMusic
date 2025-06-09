package com.example.mimusic.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.mimusic.R
import com.example.mimusic.datas.Song
import com.example.mimusic.datas.SongEl
import com.example.mimusic.utils.Mp3MetadataExtractor
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.material.imageview.ShapeableImageView
import android.graphics.BitmapFactory
import androidx.core.view.setPadding
import android.util.TypedValue
import android.widget.Button
import androidx.constraintlayout.widget.ConstraintLayout
import com.example.mimusic.services.MusicPlayer

class ArtistFragment : Fragment() {
    private lateinit var artistName: String

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_artist, container, false)

        // Получаем имя артиста из аргументов
        artistName = arguments?.getString(ARG_ARTIST_NAME) ?: "Unknown Artist"

        // Устанавливаем имя артиста в TextView
        view.findViewById<TextView>(R.id.artistNickname).text = artistName

        // Получаем все песни
        val allSongs = Mp3MetadataExtractor.getRawSongs(requireContext())

        // Фильтруем песни по артисту
        val artistSongs = allSongs.filter { it.artist == artistName }

        // Получаем контейнер для треков
        val tracksContainer = view.findViewById<LinearLayout>(R.id.tracksContainer)

        // Очищаем контейнер перед добавлением новых элементов
        tracksContainer.removeAllViews()

        // Добавляем каждый трек артиста в контейнер
        artistSongs.forEach { song ->
            addSongToContainer(tracksContainer, song)
        }

        return view
    }

    private fun addSongToContainer(container: LinearLayout, song: Song) {
        // Создаем новый элемент трека на основе макета
        val songView = LayoutInflater.from(context).inflate(
            R.layout.item_song,
            container,
            false
        ) as ConstraintLayout

        // Находим View внутри элемента
        val poster = songView.findViewById<ShapeableImageView>(R.id.galleryposter)
        val title = songView.findViewById<TextView>(R.id.gallerytext)
        val loveButton = songView.findViewById<Button>(R.id.galleryBtnLove)

        // Устанавливаем данные песни
        title.text = song.title
        poster.setImageBitmap(song.coverArt)

        // Обработчик клика на элемент
        songView.setOnClickListener {
            // Воспроизводим песню
            MusicPlayer.playSong(requireContext(), song) {
                // Callback после подготовки
            }
        }

        // Обработчик клика на кнопку "лайка"
        loveButton.setOnClickListener {
        }

        // Добавляем элемент в контейнер
        container.addView(songView)
    }

    companion object {
        private const val ARG_ARTIST_NAME = "artist_name"

        fun newInstance(artistName: String): ArtistFragment {
            val fragment = ArtistFragment()
            val args = Bundle()
            args.putString(ARG_ARTIST_NAME, artistName)
            fragment.arguments = args
            return fragment
        }
    }
}