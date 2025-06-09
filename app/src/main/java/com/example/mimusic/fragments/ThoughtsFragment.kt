package com.example.mimusic.fragments

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.mimusic.R
import com.example.mimusic.services.UserManager
import com.google.android.material.textfield.TextInputEditText

class ThoughtsFragment : Fragment() {

    private lateinit var editText: TextInputEditText
    private lateinit var sharedPreferences: android.content.SharedPreferences

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_thoughts, container, false)

        // Инициализация SharedPreferences
        sharedPreferences = requireActivity().getSharedPreferences(
            "ThoughtsPrefs",
            Context.MODE_PRIVATE
        )

        // Находим элементы UI
        editText = view.findViewById(R.id.editText)
        val cancelButton = view.findViewById<com.google.android.material.button.MaterialButton>(R.id.cancelButton)
        val saveButton = view.findViewById<com.google.android.material.button.MaterialButton>(R.id.saveButton)

        // Загружаем сохраненный текст
        loadSavedText()

        cancelButton.setOnClickListener {
            requireActivity().supportFragmentManager.popBackStack()
        }

        saveButton.setOnClickListener {
            saveText(editText.text.toString())
            requireActivity().supportFragmentManager.popBackStack()
        }

        return view
    }

    private fun loadSavedText() {
        UserManager.currentUser?.let { user ->
            val thoughts = sharedPreferences.getString(getThoughtsKey(user.login), "")
            editText.setText(thoughts)
        }
    }

    private fun saveText(text: String) {
        UserManager.currentUser?.let { user ->
            sharedPreferences.edit().apply {
                putString(getThoughtsKey(user.login), text)
                apply()
            }
        }
    }

    private fun getThoughtsKey(userLogin: String): String {
        return "user_thoughts_$userLogin"
    }
}