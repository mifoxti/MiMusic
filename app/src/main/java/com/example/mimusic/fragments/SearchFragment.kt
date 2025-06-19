package com.example.mimusic

import android.content.Context
import android.net.ConnectivityManager
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
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
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.adapters.SearchResultsAdapter
import com.example.mimusic.fragments.MusicBottomSheetFragment
import com.example.mimusic.serverSide.ApiClient
import com.example.mimusic.serverSide.GeniusApiService
import com.example.mimusic.serverSide.GeniusResponse
import com.example.mimusic.serverSide.SearchRemote
import com.example.mimusic.serverSide.SongEl
import com.example.mimusic.serverSide.ToggleLikeRequest
import kotlinx.coroutines.launch
import retrofit2.*
import retrofit2.converter.gson.GsonConverterFactory

class SearchFragment : Fragment() {
    private lateinit var searchEditText: EditText
    private lateinit var clearButton: ImageView
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: SearchResultsAdapter
    private lateinit var emptyView: TextView
    private lateinit var errorView: LinearLayout
    private lateinit var retryButton: Button
    private lateinit var offlineErrorView: LinearLayout
    private lateinit var refreshButton: Button
    private var lastQuery: String = ""

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
        offlineErrorView = view.findViewById(R.id.offlineErrorView)
        refreshButton = view.findViewById(R.id.refreshButton)

        recyclerView.layoutManager = LinearLayoutManager(context)
        adapter = SearchResultsAdapter(emptyList(),
            onLikeClick = { song, position -> toggleLike(song, position) },
            onItemClick = { song -> playSelectedSong(song) }
        )
        recyclerView.adapter = adapter

        // Retry button handling
        retryButton.setOnClickListener {
            searchSongs(lastQuery)
        }

        // Refresh button handling
        refreshButton.setOnClickListener {
            searchSongs(lastQuery)
        }

        // Обработка кнопки Enter
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

        // Настройка TextWatcher для EditText
        searchEditText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}

            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                clearButton.visibility = if (s.isNullOrEmpty()) View.GONE else View.VISIBLE
            }

            override fun afterTextChanged(s: Editable?) {}
        })

        // Обработка кнопки очистки
        clearButton.setOnClickListener {
            searchEditText.text.clear()
            hideKeyboard()
            clearButton.visibility = View.GONE
        }

        return view
    }

    private fun searchSongs(query: String) {
        lastQuery = query
        val userId = requireContext()
            .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)

        if (userId == -1) {
            showErrorPlaceholder()
            return
        }

        lifecycleScope.launch {
            try {
                val response = ApiClient.apiService.searchTracks(query, userId)
                if (response.isSuccessful) {
                    val songs = response.body() ?: emptyList()
                    showResults(songs)
                } else {
                    showErrorPlaceholder()
                }
            } catch (e: Exception) {
                Log.e("SearchFragment", "Ошибка поиска", e)
                showErrorPlaceholder()
            }
        }
    }

    private fun playSelectedSong(song: SearchRemote) {
        val convertedList = adapter.songs.map {
            com.example.mimusic.datas.Song(
                idOnServer = it.id,
                title = it.title,
                artist = it.artist ?: "",
                coverArt = it.coverArt?.let { base64 ->
                    val bytes = android.util.Base64.decode(base64, android.util.Base64.DEFAULT)
                    android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                },
            )
        }

        val selected = convertedList.find { it.idOnServer == song.id }
        if (selected != null) {
            com.example.mimusic.services.MusicPlayer.setSongList(convertedList)
            com.example.mimusic.services.MusicPlayer.playSong(requireContext(), selected)
            val bottomSheetFragment = MusicBottomSheetFragment.newInstance(selected)
            bottomSheetFragment.show(parentFragmentManager, bottomSheetFragment.tag)
        }
    }

    private fun toggleLike(song: SearchRemote, position: Int) {
        val userId = requireContext()
            .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)

        lifecycleScope.launch {
            try {
                val response = ApiClient.apiService.toggleLike(song.id, ToggleLikeRequest(userId))
                if (response.isSuccessful) {
                    val updated = response.body()?.status == true
                    adapter.updateData(
                        adapter.songs.toMutableList().apply {
                            this[position] = this[position].copy(isLiked = updated)
                        }
                    )
                }
            } catch (e: Exception) {
                Toast.makeText(requireContext(), "Ошибка лайка", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun showResults(results: List<SearchRemote>) {
        offlineErrorView.visibility = View.GONE
        if (results.isEmpty()) {
            emptyView.visibility = View.VISIBLE
            errorView.visibility = View.GONE
        } else {
            emptyView.visibility = View.GONE
            errorView.visibility = View.GONE
        }
        recyclerView.visibility = View.VISIBLE
        adapter.updateData(results)
    }

    private fun showErrorPlaceholder() {
        offlineErrorView.visibility = View.GONE
        emptyView.visibility = View.GONE
        errorView.visibility = View.VISIBLE
        recyclerView.visibility = View.GONE
    }

    private fun hideKeyboard() {
        val imm = context?.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(view?.windowToken, 0)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString("searchQuery", searchEditText.text.toString())
    }

    override fun onViewStateRestored(savedInstanceState: Bundle?) {
        super.onViewStateRestored(savedInstanceState)
        val savedQuery = savedInstanceState?.getString("searchQuery")
        searchEditText.setText(savedQuery ?: "")
    }
}