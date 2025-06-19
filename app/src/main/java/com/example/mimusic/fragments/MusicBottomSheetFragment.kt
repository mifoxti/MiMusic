package com.example.mimusic.fragments

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.SeekBar
import android.widget.TextView
import androidx.lifecycle.lifecycleScope
import com.example.mimusic.R
import com.example.mimusic.datas.Song
import com.example.mimusic.serverSide.ApiClient
import com.example.mimusic.serverSide.ToggleLikeRequest
import com.example.mimusic.services.MusicPlayer
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.google.android.material.button.MaterialButton
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MusicBottomSheetFragment : BottomSheetDialogFragment() {

    private lateinit var song: Song
    private lateinit var seekBar: SeekBar
    private lateinit var currentTimeTextView: TextView
    private lateinit var totalTimeTextView: TextView
    private lateinit var playButton: MaterialButton
    private lateinit var btnLike: MaterialButton
    private lateinit var artistTextView: TextView
    private val handler = Handler(Looper.getMainLooper())
    private val updateSeekBar = object : Runnable {
        override fun run() {
            if (MusicPlayer.isPlaying()) {
                val currentPosition = MusicPlayer.getCurrentPosition()
                seekBar.progress = currentPosition
                currentTimeTextView.text = formatTime(currentPosition)
                Log.d("MusicBottomSheetFragment", "Updating SeekBar: $currentPosition")
            }
            handler.postDelayed(this, 1000)
        }
    }

    companion object {
        private const val ARG_SONG = "song"

        fun newInstance(song: Song): MusicBottomSheetFragment {
            val fragment = MusicBottomSheetFragment()
            val args = Bundle()
            args.putParcelable(ARG_SONG, song)
            fragment.arguments = args
            return fragment
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        song = arguments?.getParcelable(ARG_SONG) ?: throw IllegalStateException("Song argument is missing")
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.modal_bottom_sheet_music, container, false)

        // Инициализация элементов интерфейса
        val songTitleTextView = view.findViewById<TextView>(R.id.songTitleTextView)
        artistTextView = view.findViewById(R.id.artistTextView)
        val profilePic = view.findViewById<com.google.android.material.imageview.ShapeableImageView>(R.id.profile_pic)
        seekBar = view.findViewById(R.id.seekBar)
        currentTimeTextView = view.findViewById(R.id.currentTimeTextView)
        totalTimeTextView = view.findViewById(R.id.totalTimeTextView)
        playButton = view.findViewById(R.id.playButton)
        btnLike = view.findViewById(R.id.galleryBtnLove)
        val prevButton = view.findViewById<MaterialButton>(R.id.iconButton)
        val nextButton = view.findViewById<MaterialButton>(R.id.nextButton)

        prevButton.setOnClickListener {
            MusicPlayer.playPrevious(requireContext()) {
                refreshUI()
            }
        }

        nextButton.setOnClickListener {
            MusicPlayer.playNext(requireContext()) {
                refreshUI()
            }
        }

        // Установка данных
        songTitleTextView.text = song.title
        artistTextView.text = song.artist ?: "Artist"
        profilePic.setImageBitmap(song.coverArt)

        // Обработка нажатия на имя артиста
        artistTextView.setOnClickListener {
            // Сворачиваем bottom sheet
            dismiss()

            // Открываем фрагмент профиля артиста
            openArtistProfile(song.artist ?: "Unknown Artist")
        }

        // Инициализация MediaPlayer
        if (MusicPlayer.getCurrentSong() != song || !MusicPlayer.isPrepared()) {
            MusicPlayer.playSong(requireContext(), song) {
                updatePlayButtonState()
                seekBar.max = MusicPlayer.getDuration()
                totalTimeTextView.text = formatTime(MusicPlayer.getDuration())
                handler.post(updateSeekBar)
            }
        } else {
            updatePlayButtonState()
            seekBar.max = MusicPlayer.getDuration()
            totalTimeTextView.text = formatTime(MusicPlayer.getDuration())
            handler.post(updateSeekBar)
        }

        // Обработка нажатия на кнопку Play/Pause
        playButton.setOnClickListener {
            if (MusicPlayer.isPlaying()) {
                MusicPlayer.pause()
                playButton.setIconResource(R.drawable.ic_play)
            } else {
                MusicPlayer.resume()
                playButton.setIconResource(R.drawable.ic_pause)
            }
        }

        // Обработка изменения SeekBar
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    MusicPlayer.seekTo(progress)
                }
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        btnLike.setOnClickListener {
            toggleFavorite()
        }

        loadLikeStatus()

        return view
    }

    private fun loadLikeStatus() {
        val userId = requireContext()
            .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)
        val trackId = song.idOnServer

        viewLifecycleOwner.lifecycleScope.launch(Dispatchers.IO) {
            try {
                val response = ApiClient.apiService.isTrackLiked(trackId, userId)
                if (response.isSuccessful) {
                    val isLiked = response.body()?.status ?: false
                    withContext(Dispatchers.Main) {
                        updateLikeButtonState(isLiked)
                    }
                } else {
                    Log.e("LikeCheck", "Server error: ${response.code()}")
                }
            } catch (e: Exception) {
                Log.e("LikeCheck", "Exception checking like", e)
            }
        }
    }

    private fun openArtistProfile(artistName: String) {
        dismiss()
        parentFragmentManager.beginTransaction()
            .replace(R.id.contentContainer, ArtistFragment.newInstance(artistName))
            .addToBackStack("artist_profile")
            .commit()
    }

    override fun onStart() {
        super.onStart()
        val bottomSheet = dialog?.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
        bottomSheet?.let {
            val behavior = BottomSheetBehavior.from(it)
            behavior.state = BottomSheetBehavior.STATE_EXPANDED
        }
    }

    private fun updatePlayButtonState() {
        if (MusicPlayer.isPlaying()) {
            playButton.setIconResource(R.drawable.ic_pause)
        } else {
            playButton.setIconResource(R.drawable.ic_play)
        }
    }

    private fun formatTime(milliseconds: Int): String {
        val minutes = milliseconds / 1000 / 60
        val seconds = milliseconds / 1000 % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacks(updateSeekBar)
    }

    private fun toggleFavorite() {
        val currentSong = MusicPlayer.getCurrentSong() ?: return
        val currentUserId = requireContext()
            .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)
        val trackId = currentSong.idOnServer
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val response = ApiClient.apiService.toggleLike(
                    trackId = trackId,
                    request = ToggleLikeRequest(currentUserId)
                )

                if (response.isSuccessful) {
                    val result = response.body()
                    val isLiked = result?.status ?: false
                    withContext(Dispatchers.Main) {
                        updateLikeButtonState(isLiked)
                    }
                } else {
                    Log.e("Like", "Error toggling like: ${response.code()}")
                }
            } catch (e: Exception) {
                Log.e("Like", "Exception toggling like", e)
            }
        }
    }


    private fun updateLikeButtonState(isLiked: Boolean) {
        btnLike.animate()
            .scaleX(1.2f)
            .scaleY(1.2f)
            .setDuration(150)
            .withEndAction {
                btnLike.setIconResource(
                    if (isLiked) R.drawable.ic_heart_filled else R.drawable.ic_heart
                )
                btnLike.animate()
                    .scaleX(1f)
                    .scaleY(1f)
                    .setDuration(150)
                    .start()
            }
            .start()
        btnLike.setIconResource(
            if (isLiked) R.drawable.ic_heart_filled else R.drawable.ic_heart
        )
    }

    private fun refreshUI() {
        val newSong = MusicPlayer.getCurrentSong() ?: return
        song = newSong
        loadLikeStatus()
        view?.findViewById<TextView>(R.id.songTitleTextView)?.text = song.title
        artistTextView.text = song.artist ?: "Artist"
        view?.findViewById<com.google.android.material.imageview.ShapeableImageView>(R.id.profile_pic)
            ?.setImageBitmap(song.coverArt)

        updatePlayButtonState()
        seekBar.max = MusicPlayer.getDuration()
        totalTimeTextView.text = formatTime(MusicPlayer.getDuration())
        handler.post(updateSeekBar)
    }
}
