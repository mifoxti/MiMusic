package com.example.mimusic

import android.os.Bundle
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.FragmentTransaction
import com.google.android.material.button.MaterialButton

class RegisterFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_register, container, false)

        // Находим кнопку registerButton
        val registerButton = view.findViewById<MaterialButton>(R.id.registerButton)

        // Обработчик нажатия на кнопку registerButton
        registerButton.setOnClickListener {
            navigateToLoginFragment()
        }

        return view
    }

    private fun navigateToLoginFragment() {
        // Создаем экземпляр LoginFragment
        val loginFragment = LoginFragment()

        // Начинаем транзакцию
        val transaction: FragmentTransaction = parentFragmentManager.beginTransaction()

        // Заменяем текущий фрагмент на LoginFragment
        transaction.replace(R.id.contentContainer, loginFragment)

        // Добавляем транзакцию в back stack, чтобы можно было вернуться назад
        transaction.addToBackStack(null)

        // Выполняем транзакцию
        transaction.commit()
    }

    override fun onResume() {
        super.onResume()
        // Восстанавливаем навигационный бар при возврате на RegisterFragment
        restoreNavigationBar()
    }

    private fun restoreNavigationBar() {
        // Проверяем, есть ли навигационный бар в bottomNavigationContainer
        val navigationFragment = parentFragmentManager.findFragmentById(R.id.bottomNavigationContainer)
        if (navigationFragment == null) {
            // Если навигационного бара нет, добавляем его
            val transaction: FragmentTransaction = parentFragmentManager.beginTransaction()
            transaction.replace(R.id.bottomNavigationContainer, BottomNavigationFragment())
            transaction.commit()
        }
    }
}