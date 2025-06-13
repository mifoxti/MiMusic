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

            requireActivity().supportFragmentManager.popBackStack()
        }

        return view
    }


    private fun saveText(text: String) {

    }
}