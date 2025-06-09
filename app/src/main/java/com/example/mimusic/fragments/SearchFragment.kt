package com.example.mimusic

import android.content.Context
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.adapters.SearchResultsAdapter
import com.example.mimusic.datas.Song
import com.example.mimusic.datas.SongEl
import com.example.mimusic.fragments.MusicBottomSheetFragment
import com.example.mimusic.services.MusicPlayer
import com.example.mimusic.services.UserManager
import com.example.mimusic.utils.Mp3MetadataExtractor

class SearchFragment : Fragment() {
    private lateinit var searchEditText: EditText
    private lateinit var clearButton: ImageView
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: SearchResultsAdapter
    private lateinit var emptyView: TextView
    private lateinit var errorView: LinearLayout
    private lateinit var retryButton: Button
    private var lastQuery: String = ""
    private var allSongs: List<Song> = emptyList()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val view = inflater.inflate(R.layout.fragment_search, container, false)

        searchEditText = view.findViewById(R.id.search_edit_text)
        clearButton = view.findViewById(R.id.clear_button)
        recyclerView = view.findViewById(R.id.search_results_recycler_view)
        emptyView = view.findViewById(R.id.emptyView)
        errorView = view.findViewById(R.id.errorView)
        retryButton = view.findViewById(R.id.retryButton)

        allSongs = Mp3MetadataExtractor.getRawSongs(requireContext())

        setupRecyclerView()
        setupSearchListeners()
        setupRetryButton()

        return view
    }

    private fun setupRecyclerView() {
        recyclerView.layoutManager = LinearLayoutManager(context)
        adapter = SearchResultsAdapter(
            songs = emptyList(),
            onItemClick = { songEl ->
                allSongs.find { it.hashCode() == songEl.id }?.let { song ->
                    playSong(song)
                }
            },
            onLoveClick = { songEl ->
                toggleFavorite(songEl.id)
            }
        )
        recyclerView.adapter = adapter
    }

    private fun setupSearchListeners() {
        searchEditText.setOnKeyListener { _, keyCode, event ->
            if (keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_DOWN) {
                val query = searchEditText.text.toString()
                if (query.isNotEmpty()) {
                    searchSongs(query)
                    hideKeyboard()
                }
                true
            } else {
                false
            }
        }

        searchEditText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}

            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                clearButton.visibility = if (s.isNullOrEmpty()) View.GONE else View.VISIBLE
                if (!s.isNullOrEmpty()) {
                    searchSongs(s.toString())
                } else {
                    showResults(emptyList())
                }
            }

            override fun afterTextChanged(s: Editable?) {}
        })

        clearButton.setOnClickListener {
            searchEditText.text.clear()
            hideKeyboard()
            clearButton.visibility = View.GONE
            showResults(emptyList())
        }
    }

    private fun setupRetryButton() {
        retryButton.setOnClickListener {
            searchSongs(lastQuery)
        }
    }

    private fun searchSongs(query: String) {
        lastQuery = query
        val normalizedQuery = query.lowercase().trim()

        if (normalizedQuery.isEmpty()) {
            showResults(emptyList())
            return
        }

        val results = allSongs.filter { song ->
            song.title.lowercase().contains(normalizedQuery) ||
                    song.artist.lowercase().contains(normalizedQuery) ||
                    song.album.lowercase().contains(normalizedQuery)
        }.map { song ->
            song.toSongEl().copy(
                isLoved = UserManager.currentUser?.likedSongs?.contains(song.filePath) ?: false
            )
        }

        showResults(results)
    }

    private fun showResults(results: List<SongEl>) {
        if (results.isEmpty()) {
            emptyView.visibility = View.VISIBLE
            errorView.visibility = View.GONE
            recyclerView.visibility = View.GONE
        } else {
            emptyView.visibility = View.GONE
            errorView.visibility = View.GONE
            recyclerView.visibility = View.VISIBLE

            val foundSongs = results.mapNotNull { songEl ->
                allSongs.find { it.hashCode() == songEl.id }
            }
            MusicPlayer.setSongList(foundSongs)

            adapter.updateData(results)
        }
    }

    private fun showErrorPlaceholder() {
        emptyView.visibility = View.GONE
        errorView.visibility = View.VISIBLE
        recyclerView.visibility = View.GONE
    }

    private fun hideKeyboard() {
        val imm = context?.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(view?.windowToken, 0)
    }

    private fun playSong(song: Song) {
        MusicPlayer.playSong(requireContext(), song) {
            showNowPlaying(song)
        }
    }

    private fun showNowPlaying(song: Song) {
        val bottomSheet = MusicBottomSheetFragment.newInstance(song)
        bottomSheet.show(parentFragmentManager, bottomSheet.tag)
    }

    private fun toggleFavorite(songId: Int) {
        val song = allSongs.find { it.hashCode() == songId }
        song?.let {
            val currentUser = UserManager.currentUser
            if (currentUser != null) {
                val isLiked = currentUser.likedSongs.contains(it.filePath)
                if (isLiked) {
                    UserManager.removeLikedSong(it.filePath)
                } else {
                    UserManager.addLikedSong(it.filePath)
                }

                // Обновляем отображение в адаптере
                adapter.updateSongLikeStatus(songId, !isLiked)
            }
        }
    }


}