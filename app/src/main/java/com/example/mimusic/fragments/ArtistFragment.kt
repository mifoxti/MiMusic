package com.example.mimusic.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.mimusic.R
import com.example.mimusic.datas.Song
import com.example.mimusic.services.MusicPlayer
import com.example.mimusic.services.UserManager
import com.example.mimusic.utils.Mp3MetadataExtractor
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.material.imageview.ShapeableImageView
import androidx.core.view.setPadding
import android.util.TypedValue
import android.widget.Button
import androidx.constraintlayout.widget.ConstraintLayout
import com.google.android.material.button.MaterialButton

class ArtistFragment : Fragment() {
    private lateinit var artistName: String
    private val songs = mutableListOf<Song>()
    private val songViews = mutableListOf<View>()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_artist, container, false)

        artistName = arguments?.getString(ARG_ARTIST_NAME) ?: "Unknown Artist"
        view.findViewById<TextView>(R.id.artistNickname).text = artistName

        val allSongs = Mp3MetadataExtractor.getRawSongs(requireContext())
        songs.clear()
        songs.addAll(allSongs.filter { it.artist == artistName })

        val tracksContainer = view.findViewById<LinearLayout>(R.id.tracksContainer)
        tracksContainer.removeAllViews()
        songViews.clear()

        songs.forEach { song ->
            addSongToContainer(tracksContainer, song)
        }

        return view
    }

    private fun addSongToContainer(container: LinearLayout, song: Song) {
        val songView = LayoutInflater.from(context).inflate(
            R.layout.item_song,
            container,
            false
        ) as ConstraintLayout

        val poster = songView.findViewById<ShapeableImageView>(R.id.galleryposter)
        val title = songView.findViewById<TextView>(R.id.gallerytext)
        val loveButton = songView.findViewById<MaterialButton>(R.id.galleryBtnLove)

        title.text = song.title
        poster.setImageBitmap(song.coverArt)

        // Обновляем состояние кнопки лайка
        updateLoveButton(loveButton, song)

        songView.setOnClickListener {
            MusicPlayer.playSong(requireContext(), song)
        }

        loveButton.setOnClickListener {
            toggleFavorite(song, loveButton)
        }

        container.addView(songView)
        songViews.add(songView)
    }

    private fun toggleFavorite(song: Song, button: MaterialButton) {
        UserManager.currentUser?.let { user ->
            val isLiked = user.likedSongs.contains(song.filePath)
            if (isLiked) {
                UserManager.removeLikedSong(song.filePath)
            } else {
                UserManager.addLikedSong(song.filePath)
            }
            updateLoveButton(button, song)
        } ?: run {

        }
    }

    private fun updateLoveButton(button: MaterialButton, song: Song) {
        val isLiked = UserManager.currentUser?.likedSongs?.contains(song.filePath) ?: false
        button.setIconResource(
            if (isLiked) R.drawable.ic_heart_filled else R.drawable.ic_heart
        )
    }

    fun updateLikedSongs() {
        songViews.forEachIndexed { index, view ->
            val loveButton = view.findViewById<MaterialButton>(R.id.galleryBtnLove)
            updateLoveButton(loveButton, songs[index])
        }
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