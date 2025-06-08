package com.example.mimusic.fragments

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.SeekBar
import android.widget.TextView
import com.example.mimusic.R
import com.example.mimusic.datas.Song
import com.example.mimusic.services.MusicPlayer
import com.example.mimusic.utils.Mp3MetadataExtractor
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.google.android.material.button.MaterialButton
import com.google.android.material.imageview.ShapeableImageView

class MusicBottomSheetFragment : BottomSheetDialogFragment() {
    private lateinit var song: Song
    private lateinit var seekBar: SeekBar
    private lateinit var currentTimeTextView: TextView
    private lateinit var totalTimeTextView: TextView
    private lateinit var playButton: MaterialButton
    private lateinit var songTitleTextView: TextView
    private lateinit var profilePic: ShapeableImageView
    private lateinit var artistTextView: TextView
    private val handler = Handler(Looper.getMainLooper())
    private val updateSeekBar = object : Runnable {
        override fun run() {
            if (MusicPlayer.isPlaying()) {
                val currentPosition = MusicPlayer.getCurrentPosition()
                seekBar.progress = currentPosition
                currentTimeTextView.text = formatTime(currentPosition)
            }
            handler.postDelayed(this, 100)
        }
    }

    private val songChangedListener: () -> Unit = {
        handler.post {
            MusicPlayer.getCurrentSong()?.let { currentSong ->
                updateSongInfo(currentSong)
                updatePlayButtonState()
                seekBar.max = MusicPlayer.getDuration()
                totalTimeTextView.text = formatTime(MusicPlayer.getDuration())
            }
        }
    }

    private val playbackStateListener: () -> Unit = {
        handler.post {
            updatePlayButtonState()
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

        MusicPlayer.addSongChangedListener(songChangedListener)
        MusicPlayer.addPlaybackStateListener(playbackStateListener)

        song = arguments?.getParcelable(ARG_SONG) ?: throw IllegalStateException("Song argument is missing")
        val songs = Mp3MetadataExtractor.getRawSongs(requireContext())
        MusicPlayer.setSongList(songs)
        Log.d("MusicBottomSheet", "Song list set with ${songs.size} songs")
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.modal_bottom_sheet_music, container, false)

        songTitleTextView = view.findViewById(R.id.songTitleTextView)
        artistTextView = view.findViewById(R.id.artistTextView)
        profilePic = view.findViewById(R.id.profile_pic)
        seekBar = view.findViewById(R.id.seekBar)
        currentTimeTextView = view.findViewById(R.id.currentTimeTextView)
        totalTimeTextView = view.findViewById(R.id.totalTimeTextView)
        playButton = view.findViewById(R.id.playButton)
        val nextButton = view.findViewById<MaterialButton>(R.id.nextButton)
        val prevButton = view.findViewById<MaterialButton>(R.id.iconButton)

        updateSongInfo(song)
        profilePic.setImageBitmap(song.coverArt)

        MusicPlayer.addSongChangedListener(songChangedListener)
        MusicPlayer.addPlaybackStateListener(playbackStateListener)

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

        playButton.setOnClickListener {
            if (MusicPlayer.isPlaying()) {
                MusicPlayer.pause()
            } else {
                MusicPlayer.resume()
            }
        }

        nextButton.setOnClickListener {
            MusicPlayer.playNext(requireContext())
        }

        prevButton.setOnClickListener {
            MusicPlayer.playPrevious(requireContext())
        }

        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    MusicPlayer.seekTo(progress)
                }
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        return view
    }

    private fun updateSongInfo(song: Song) {
        songTitleTextView.text = song.title
        artistTextView.text = song.artist ?: "Artist"
        profilePic.setImageBitmap(song.coverArt)
    }

    private fun updatePlayButtonState() {
        playButton.setIconResource(
            if (MusicPlayer.isPlaying()) R.drawable.ic_pause else R.drawable.ic_play
        )
    }

    private fun formatTime(milliseconds: Int): String {
        val minutes = milliseconds / 1000 / 60
        val seconds = milliseconds / 1000 % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacks(updateSeekBar)
        MusicPlayer.removeSongChangedListener(songChangedListener)
        MusicPlayer.removePlaybackStateListener(playbackStateListener)
    }

    override fun onStart() {
        super.onStart()
        val bottomSheet = dialog?.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
        bottomSheet?.let {
            val behavior = BottomSheetBehavior.from(it)
            behavior.state = BottomSheetBehavior.STATE_EXPANDED
        }
    }
}