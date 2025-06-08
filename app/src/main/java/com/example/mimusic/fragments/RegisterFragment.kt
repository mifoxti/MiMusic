package com.example.mimusic.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.mimusic.MainActivity
import com.example.mimusic.R
import com.example.mimusic.services.UserManager
import com.google.android.material.snackbar.Snackbar
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.button.MaterialButton

class RegisterFragment : Fragment() {

    private lateinit var loginText: TextInputEditText
    private lateinit var passwordText1: TextInputEditText
    private lateinit var passwordText2: TextInputEditText

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_register, container, false)

        // Инициализация полей ввода
        loginText = view.findViewById(R.id.loginText)
        passwordText1 = view.findViewById(R.id.passwordText1)
        passwordText2 = view.findViewById(R.id.passwordText)

        // Кнопки
        val registerButton = view.findViewById<MaterialButton>(R.id.registerButton)
        val loginBtn = view.findViewById<MaterialButton>(R.id.lgnBtn)

        // Слушатели
        registerButton.setOnClickListener { tryRegister() }
        loginBtn.setOnClickListener { navigateToLoginFragment() }

        return view
    }

    private fun tryRegister() {
        val login = loginText.text.toString()
        val password1 = passwordText1.text.toString()
        val password2 = passwordText2.text.toString()

        if (login.isEmpty() || password1.isEmpty()) {
            showSnackbar("Логин и пароль не могут быть пустыми")
            return
        }

        if (password1 != password2) {
            showSnackbar("Пароли не совпадают")
            return
        }

        if (UserManager.register(login, password1)) {
            Log.d("MainActivity", "UserManager.currentUser = ${UserManager.currentUser}")
            showSnackbar("Регистрация успешна!")
            UserManager.login(login, password1)
            (activity as? MainActivity)?.onLoginSuccess()
        } else {
            showSnackbar("Пользователь с таким логином уже существует")
        }
    }

    private fun showSnackbar(message: String) {
        view?.let {
            Snackbar.make(it, message, Snackbar.LENGTH_SHORT).show()
        }
    }

    private fun navigateToLoginFragment() {
        parentFragmentManager.beginTransaction()
            .replace(R.id.contentContainer, LoginFragment())
            .addToBackStack("login")
            .commit()
    }
}