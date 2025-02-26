package com.example.mimusic

import android.os.Bundle
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.FragmentManager
import com.google.android.material.button.MaterialButton

class ProfileFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_profile, container, false)

        // Находим кнопку настроек
        val settingsButton = view.findViewById<MaterialButton>(R.id.settingsButton)

        // Обработчик нажатия на кнопку настроек
        settingsButton.setOnClickListener {
            clearFragmentsAndOpenRegister()
        }

        return view
    }

    private fun clearFragmentsAndOpenRegister() {
        // Получаем FragmentManager
        val fragmentManager: FragmentManager = parentFragmentManager

        // Очищаем все фрагменты из back stack
        fragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)

        // Заменяем фрагмент в contentContainer на RegisterFragment
        fragmentManager.beginTransaction()
            .replace(R.id.contentContainer, RegisterFragment())
            .addToBackStack("register_fragment") // Добавляем транзакцию в back stack
            .commit()

        // Очищаем bottomNavigationContainer (если нужно)
        fragmentManager.beginTransaction()
            .replace(R.id.bottomNavigationContainer, EmptyFragment()) // Замените EmptyFragment на нужный фрагмент или оставьте пустым
            .addToBackStack("empty_fragment") // Добавляем транзакцию в back stack
            .commit()
    }
}