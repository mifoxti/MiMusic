package com.example.mimusic

import android.content.Context
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import retrofit2.*
import retrofit2.converter.gson.GsonConverterFactory

class SearchFragment : Fragment() {

    private lateinit var searchEditText: EditText
    private lateinit var clearButton: ImageView
    private lateinit var recyclerView: RecyclerView
    private lateinit var historyRecyclerView: RecyclerView
    private lateinit var adapter: SearchResultsAdapter
    private lateinit var historyAdapter: SearchHistoryAdapter
    private lateinit var emptyView: TextView
    private lateinit var clearHistoryButton: Button
    private lateinit var progressBar: ProgressBar
    private var lastQuery: String = ""

    private val PREFS_NAME = "search_prefs"
    private val HISTORY_KEY = "search_history"
    private val MAX_HISTORY_SIZE = 10

    private val apiService: GeniusApiService by lazy {
        Retrofit.Builder()
            .baseUrl("https://api.genius.com/")
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(GeniusApiService::class.java)
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val view = inflater.inflate(R.layout.fragment_search, container, false)

        searchEditText = view.findViewById(R.id.search_edit_text)
        clearButton = view.findViewById(R.id.clear_button)
        recyclerView = view.findViewById(R.id.search_results_recycler_view)
        historyRecyclerView = view.findViewById(R.id.history_recycler_view)
        emptyView = view.findViewById(R.id.emptyView)
        clearHistoryButton = view.findViewById(R.id.clear_history_button)
        progressBar = view.findViewById(R.id.progress_bar)

        recyclerView.layoutManager = LinearLayoutManager(context)
        historyRecyclerView.layoutManager = LinearLayoutManager(context)

        adapter = SearchResultsAdapter(emptyList())
        historyAdapter = SearchHistoryAdapter(emptyList()) { query ->
            searchEditText.setText(query)
            performSearch(query)
        }

        recyclerView.adapter = adapter
        historyRecyclerView.adapter = historyAdapter

        clearHistoryButton.setOnClickListener { clearSearchHistory() }

        clearButton.setOnClickListener {
            searchEditText.setText("")
            showSearchHistory()
            clearButton.visibility = View.GONE
            emptyView.visibility = View.GONE
        }

        searchEditText.addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(s: Editable?) {
                val query = s.toString()

                // Показываем кнопку очистки, если есть текст
                clearButton.visibility = if (query.isNotEmpty()) View.VISIBLE else View.GONE

                // Показываем историю, если текст пустой и поле в фокусе
                if (query.isEmpty() && searchEditText.hasFocus()) {
                    showSearchHistory()
                }
            }

            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
        })

        searchEditText.setOnEditorActionListener { _, actionId, event ->
            if (actionId == EditorInfo.IME_ACTION_SEARCH || (event?.keyCode == KeyEvent.KEYCODE_ENTER)) {
                val query = searchEditText.text.toString().trim()
                if (query.isNotEmpty()) {
                    performSearch(query)
                }
                true
            } else {
                false
            }
        }

        searchEditText.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus && searchEditText.text.isEmpty()) {
                showSearchHistory()
            }
        }

        return view
    }

    private fun performSearch(query: String) {
        if (query == lastQuery) return

        lastQuery = query
        saveSearchQuery(query)

        progressBar.visibility = View.VISIBLE  // Показываем ProgressBar

        apiService.searchSongs(
            "Bearer 9pUXlzf6HUyVHh5A6CVNEc-NHzSf85S0HqzrXAGVwZTAEoMMWDgyHbZOESWxA0Ub",
            query
        ).enqueue(object : Callback<GeniusResponse> {
            override fun onResponse(call: Call<GeniusResponse>, response: Response<GeniusResponse>) {
                progressBar.visibility = View.GONE  // Скрываем ProgressBar

                if (response.isSuccessful) {
                    response.body()?.response?.hits?.map { it.result }?.let { showResults(it) }
                } else {
                    showErrorPlaceholder()
                }
            }

            override fun onFailure(call: Call<GeniusResponse>, t: Throwable) {
                progressBar.visibility = View.GONE  // Скрываем ProgressBar
                showErrorPlaceholder()
            }
        })
    }


    private fun saveSearchQuery(query: String) {
        val sharedPreferences = requireContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val history = getSearchHistory().toMutableList()

        history.remove(query)
        history.add(0, query)

        if (history.size > MAX_HISTORY_SIZE) {
            history.removeAt(history.size - 1)
        }

        sharedPreferences.edit().putStringSet(HISTORY_KEY, history.toSet()).apply()
    }

    private fun getSearchHistory(): List<String> {
        val sharedPreferences = requireContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return sharedPreferences.getStringSet(HISTORY_KEY, emptySet())?.toList() ?: emptyList()
    }

    private fun showSearchHistory() {
        val history = getSearchHistory()
        historyAdapter.updateData(history)

        historyRecyclerView.visibility = if (history.isEmpty()) View.GONE else View.VISIBLE
        clearHistoryButton.visibility = if (history.isEmpty()) View.GONE else View.VISIBLE
    }

    private fun clearSearchHistory() {
        val sharedPreferences = requireContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        sharedPreferences.edit().remove(HISTORY_KEY).apply()
        showSearchHistory()
    }

    private fun showResults(songs: List<SongEl>) {
        adapter.updateData(songs)

        if (songs.isEmpty()) {
            emptyView.visibility = View.VISIBLE
            emptyView.text = "Нет результатов"
        } else {
            emptyView.visibility = View.GONE
        }
    }

    private fun showErrorPlaceholder() {
        emptyView.visibility = View.VISIBLE
        emptyView.text = "Произошла ошибка. Попробуйте снова."
    }
}
