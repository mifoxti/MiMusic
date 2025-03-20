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
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
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
    private var lastQuery: String = ""

    private val apiService: GeniusApiService by lazy {
        Retrofit.Builder()
            .baseUrl("https://api.genius.com/")
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(GeniusApiService::class.java)
    }

    private val isApiAvailable: Boolean
        get() {
            val connectivityManager =
                context?.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val networkInfo = connectivityManager.activeNetworkInfo
            return networkInfo != null && networkInfo.isConnected
        }

    private val fakeSongs = listOf(
        SongEl(1, "Fake Song 1", "mifoxti", "https://images.genius.com/95cfea0187b37c7731e11d54b07d2415.1000x1000x1.png"),
        SongEl(2, "Fake Song 2", "mifoxti", "https://images.genius.com/95cfea0187b37c7731e11d54b07d2415.1000x1000x1.png")
    )

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

        recyclerView.layoutManager = LinearLayoutManager(context)
        adapter = SearchResultsAdapter(emptyList())
        recyclerView.adapter = adapter

        // Retry button handling
        retryButton.setOnClickListener {
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
                // Показываем или скрываем кнопку очистки
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
        if (isApiAvailable) {
            Log.d("SearchFragment", "Searching for: $query")
            val token = "не дам"
            apiService.searchSongs(token, query).enqueue(object : Callback<GeniusResponse> {
                override fun onResponse(
                    call: Call<GeniusResponse>,
                    response: Response<GeniusResponse>
                ) {
                    if (response.isSuccessful) {
                        response.body()?.response?.hits?.map { it.result }?.let {
                            showResults(it)
                        }
                    } else {
                        showErrorPlaceholder()
                    }
                }

                override fun onFailure(call: Call<GeniusResponse>, t: Throwable) {
                    showErrorPlaceholder()
                }
            })
        } else {
            adapter.updateData(fakeSongs)
        }
    }

    private fun showResults(results: List<SongEl>) {
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