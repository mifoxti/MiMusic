package com.example.mimusic.fragments

import android.content.Context
import android.graphics.BitmapFactory
import android.os.Bundle
import android.util.Base64
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.example.mimusic.R
import com.example.mimusic.datas.Song
import com.example.mimusic.serverSide.ApiClient
import com.example.mimusic.serverSide.ArtistRemote
import com.example.mimusic.serverSide.ArtistTrackRemote
import com.example.mimusic.serverSide.ToggleLikeRequest
import com.example.mimusic.services.MusicPlayer
import com.google.android.material.button.MaterialButton
import com.google.android.material.imageview.ShapeableImageView
import kotlinx.coroutines.launch

class ArtistFragment : Fragment() {

    private lateinit var artistName: String
    private lateinit var tracksContainer: LinearLayout
    private val artistTracks = mutableListOf<ArtistTrackRemote>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        artistName = arguments?.getString(ARG_ARTIST_NAME) ?: ""
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_artist, container, false)
        tracksContainer = view.findViewById(R.id.tracksContainer)

        val artistText = view.findViewById<TextView>(R.id.artistNickname)
        artistText.text = artistName

        fetchArtistInfo(view)

        return view
    }

    private fun fetchArtistInfo(view: View) {
        lifecycleScope.launch {
            try {
                val userId = requireContext()
                    .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
                    .getInt("currentUserId", -1)

                val response = ApiClient.apiService.getArtistInfo(artistName, userId)
                if (response.isSuccessful) {
                    val artistInfo: ArtistRemote = response.body()!!
                    view.findViewById<TextView>(R.id.artistThoughts).text = artistInfo.thoughts
                    displaySongs(artistInfo.songs)
                } else {
                    Toast.makeText(requireContext(), "Ошибка: ${response.code()}", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(requireContext(), "Ошибка загрузки: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun displaySongs(songs: List<ArtistTrackRemote>) {
        artistTracks.clear()
        artistTracks.addAll(songs)

        tracksContainer.removeAllViews()

        for ((index, track) in artistTracks.withIndex()) {
            val item = layoutInflater.inflate(R.layout.item_song, tracksContainer, false)

            val titleView = item.findViewById<TextView>(R.id.gallerytext)
            val imageView = item.findViewById<ShapeableImageView>(R.id.galleryposter)
            val likeBtn = item.findViewById<MaterialButton>(R.id.galleryBtnLove)

            titleView.text = track.title

            if (!track.coverArt.isNullOrBlank()) {
                val bytes = Base64.decode(track.coverArt, Base64.DEFAULT)
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                imageView.setImageBitmap(bitmap)
            } else {
                imageView.setImageResource(R.drawable.music_image)
            }

            val iconRes = if (track.isLiked) R.drawable.ic_heart_filled else R.drawable.ic_heart
            likeBtn.setIconResource(iconRes)

            likeBtn.setOnClickListener {
                toggleLike(track, likeBtn)
            }

            item.setOnClickListener {
                val songsToPlay = artistTracks.map { tr ->
                    Song(
                        idOnServer = tr.id,
                        title = tr.title,
                        artist = tr.artist,
                        coverArt = tr.coverArt?.let {
                            val bytes = Base64.decode(it, Base64.DEFAULT)
                            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                        }
                    )
                }

                MusicPlayer.setSongList(songsToPlay)
                MusicPlayer.playSong(requireContext(), songsToPlay[index])
            }

            tracksContainer.addView(item)
        }
    }

    private fun toggleLike(track: ArtistTrackRemote, button: MaterialButton) {
        val userId = requireContext()
            .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)

        lifecycleScope.launch {
            try {
                val response = ApiClient.apiService.toggleLike(
                    trackId = track.id,
                    request = ToggleLikeRequest(userId)
                )
                if (response.isSuccessful) {
                    val isNowLiked = response.body()?.status == true
                    track.isLiked = isNowLiked
                    val icon = if (isNowLiked) R.drawable.ic_heart_filled else R.drawable.ic_heart
                    button.setIconResource(icon)
                } else {
                    Toast.makeText(requireContext(), "Ошибка: ${response.code()}", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(requireContext(), "Ошибка сети: ${e.message}", Toast.LENGTH_SHORT).show()
            }
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
