package com.example.mimusic.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.mimusic.R

class ThoughtsFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_thoughts, container, false)

        // Находим кнопки
        val cancelButton = view.findViewById<com.google.android.material.button.MaterialButton>(R.id.cancelButton)
        val saveButton = view.findViewById<com.google.android.material.button.MaterialButton>(R.id.saveButton)

        // Обработка нажатия "Отмена" - просто закрываем фрагмент
        cancelButton.setOnClickListener {
            requireActivity().supportFragmentManager.popBackStack()
        }

        // Обработка нажатия "Сохранить" - сохраняем данные (если нужно) и закрываем
        saveButton.setOnClickListener {
            // Здесь можно добавить логику сохранения данных
            // Например:
            // val editText = view.findViewById<TextInputEditText>(R.id.your_edit_text_id)
            // val text = editText.text.toString()
            // saveText(text)

            requireActivity().supportFragmentManager.popBackStack()
        }

        return view
    }

    // Пример функции для сохранения текста (реализуйте по необходимости)
    private fun saveText(text: String) {
        // Реализация сохранения (в SharedPreferences, БД и т.д.)
    }
}