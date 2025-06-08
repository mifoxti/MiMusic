package com.example.mimusic.fragments

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import androidx.fragment.app.Fragment
import com.example.mimusic.R
import com.example.mimusic.services.UserManager
import com.google.android.material.snackbar.Snackbar
import com.google.android.material.textfield.TextInputEditText
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.example.mimusic.MainActivity

class LoginFragment : Fragment() {

    private lateinit var loginText: TextInputEditText
    private lateinit var passwordText: TextInputEditText

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_login, container, false)

        loginText = view.findViewById(R.id.loginText)
        passwordText = view.findViewById(R.id.passwordText)

        val loginButton = view.findViewById<Button>(R.id.loginButton)
        loginButton.setOnClickListener {
            tryLogin()
        }

        val registerButton = view.findViewById<Button>(R.id.regBtn)
        registerButton.setOnClickListener {
            navigateToRegisterFragment()
        }

        return view
    }

    private fun navigateToRegisterFragment() {
        parentFragmentManager.beginTransaction()
            .replace(R.id.contentContainer, RegisterFragment())
            .addToBackStack("register")
            .commit()
    }

    private fun tryLogin() {
        val login = loginText.text.toString()
        val password = passwordText.text.toString()

        if (login.isEmpty() || password.isEmpty()) {
            showSnackbar("Логин и пароль не могут быть пустыми")
            return
        }

        if (!checkInternetConnection()) {
            showSnackbar("Нет интернет-соединения")
            return
        }

        if (UserManager.login(login, password)) {
            showSnackbar("Успешный вход!")
            UserManager.login(login, password)
            (requireActivity() as MainActivity).onLoginSuccess()
        } else {
            showSnackbar("Неверный логин или пароль")
        }
    }

    private fun showSnackbar(message: String) {
        view?.let {
            Snackbar.make(it, message, Snackbar.LENGTH_SHORT).show()
        }
    }

    private fun checkInternetConnection(): Boolean {
        val connectivityManager = requireContext().getSystemService(ConnectivityManager::class.java)
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }
}