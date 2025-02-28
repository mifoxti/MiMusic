package com.example.mimusic

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.SeekBar
import android.widget.TextView
import androidx.fragment.app.FragmentManager
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.google.android.material.button.MaterialButton

class MusicBottomSheetFragment : BottomSheetDialogFragment() {

    private lateinit var song: Song
    private lateinit var seekBar: SeekBar
    private lateinit var currentTimeTextView: TextView
    private lateinit var totalTimeTextView: TextView
    private lateinit var playButton: MaterialButton
    private val handler = Handler(Looper.getMainLooper())
    private val updateSeekBar = object : Runnable {
        override fun run() {
            if (MusicPlayer.isPlaying()) {
                val currentPosition = MusicPlayer.getCurrentPosition()
                seekBar.progress = currentPosition
                currentTimeTextView.text = formatTime(currentPosition)
                Log.d("MusicBottomSheetFragment", "Updating SeekBar: $currentPosition")
            }
            handler.postDelayed(this, 1000) // Обновляем каждую секунду
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
        // Получаем данные о песне из аргументов
        song = arguments?.getParcelable(ARG_SONG) ?: throw IllegalStateException("Song argument is missing")
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.modal_bottom_sheet_music, container, false)

        // Инициализация элементов интерфейса
        val songTitleTextView = view.findViewById<TextView>(R.id.songTitleTextView)
        val artistTextView = view.findViewById<TextView>(R.id.artistTextView)
        val profilePic = view.findViewById<com.google.android.material.imageview.ShapeableImageView>(R.id.profile_pic)
        seekBar = view.findViewById(R.id.seekBar)
        currentTimeTextView = view.findViewById(R.id.currentTimeTextView)
        totalTimeTextView = view.findViewById(R.id.totalTimeTextView)
        playButton = view.findViewById(R.id.playButton)

        // Установка данных
        songTitleTextView.text = song.title
        artistTextView.text = "Artist" // Замените на реального исполнителя, если есть данные
        profilePic.setImageBitmap(song.coverArt)

        // Инициализация MediaPlayer (если песня не играет)
        if (MusicPlayer.getCurrentSong() != song || !MusicPlayer.isPrepared()) {
            MusicPlayer.playSong(requireContext(), song) {
                // Колбэк, вызываемый после подготовки MediaPlayer
                updatePlayButtonState()
                seekBar.max = MusicPlayer.getDuration()
                totalTimeTextView.text = formatTime(MusicPlayer.getDuration())
                handler.post(updateSeekBar) // Запускаем обновление SeekBar
            }
        } else {
            // Если MediaPlayer уже готов, обновляем UI сразу
            updatePlayButtonState()
            seekBar.max = MusicPlayer.getDuration()
            totalTimeTextView.text = formatTime(MusicPlayer.getDuration())
            handler.post(updateSeekBar)
        }

        // Обработка нажатия на кнопку Play/Pause
        playButton.setOnClickListener {
            if (MusicPlayer.isPlaying()) {
                MusicPlayer.pause()
                playButton.setIconResource(R.drawable.ic_play) // Иконка "Play"
            } else {
                MusicPlayer.resume()
                playButton.setIconResource(R.drawable.ic_pause) // Иконка "Pause"
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

        return view
    }

    override fun onStart() {
        super.onStart()
        // Устанавливаем BottomSheet в развернутое состояние
        val bottomSheet = dialog?.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
        bottomSheet?.let {
            val behavior = BottomSheetBehavior.from(it)
            behavior.state = BottomSheetBehavior.STATE_EXPANDED
        }
    }

    private fun updatePlayButtonState() {
        if (MusicPlayer.isPlaying()) {
            playButton.setIconResource(R.drawable.ic_pause) // Иконка "Pause"
        } else {
            playButton.setIconResource(R.drawable.ic_play) // Иконка "Play"
        }
    }

    private fun formatTime(milliseconds: Int): String {
        val minutes = milliseconds / 1000 / 60
        val seconds = milliseconds / 1000 % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacks(updateSeekBar) // Останавливаем обновление SeekBar
    }
}