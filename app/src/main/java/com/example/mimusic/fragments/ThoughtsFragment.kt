package com.example.mimusic.fragments

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.example.mimusic.R
import com.example.mimusic.serverSide.ApiClient
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.launch

class ThoughtsFragment : Fragment() {

    private lateinit var thoughtsEditText: TextInputEditText

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_thoughts, container, false)

        val cancelButton = view.findViewById<MaterialButton>(R.id.cancelButton)
        val saveButton = view.findViewById<MaterialButton>(R.id.saveButton)
        thoughtsEditText = view.findViewById(R.id.textInputEditText)

        cancelButton.setOnClickListener {
            hideKeyboard()
            requireActivity().supportFragmentManager.popBackStack()
        }

        saveButton.setOnClickListener {
            val text = thoughtsEditText.text?.toString()?.trim() ?: ""
            if (text.isNotEmpty()) {
                saveText(text)
            } else {
                Toast.makeText(requireContext(), "Введите текст мысли", Toast.LENGTH_SHORT).show()
            }
        }

        fetchCurrentThought()

        return view
    }

    private fun fetchCurrentThought() {
        val userId = requireContext()
            .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)

        if (userId == -1) return

        lifecycleScope.launch {
            try {
                val response = ApiClient.apiService.getThought(userId)
                if (response.isSuccessful) {
                    val thought = response.body()?.get("thought") ?: ""
                    thoughtsEditText.setText(thought)
                } else {
                    Toast.makeText(requireContext(), "Не удалось загрузить мысли", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(requireContext(), "Ошибка: ${e.localizedMessage}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun saveText(text: String) {
        val userId = requireContext()
            .getSharedPreferences("UserPrefs", Context.MODE_PRIVATE)
            .getInt("currentUserId", -1)

        if (userId == -1) return

        lifecycleScope.launch {
            try {
                val response = ApiClient.apiService.updateThought(userId, text)
                if (response.isSuccessful) {
                    Toast.makeText(requireContext(), "Мысли успешно обновлены", Toast.LENGTH_SHORT).show()
                    hideKeyboard()
                    requireActivity().supportFragmentManager.popBackStack()
                } else {
                    Toast.makeText(requireContext(), "Ошибка при сохранении", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(requireContext(), "Ошибка сети: ${e.localizedMessage}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun hideKeyboard() {
        val imm = context?.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(view?.windowToken, 0)
    }
}
