package com.example.mimusic.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentTransaction
import androidx.lifecycle.lifecycleScope
import com.example.mimusic.MainActivity
import com.example.mimusic.R
import com.example.mimusic.serverSide.ApiClient
import com.example.mimusic.serverSide.RegisterRequest
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.launch

class RegisterFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_register, container, false)

        val registerButton = view.findViewById<MaterialButton>(R.id.registerButton)
        val loginButton = view.findViewById<MaterialButton>(R.id.lgnBtn)

        registerButton.setOnClickListener {
            val login = view.findViewById<TextInputEditText>(R.id.loginText)?.text?.toString()?.trim()
            val password1 = view.findViewById<TextInputEditText>(R.id.passwordText1)?.text?.toString()
            val password2 = view.findViewById<TextInputEditText>(R.id.passwordText)?.text?.toString()

            if (login.isNullOrEmpty() || password1.isNullOrEmpty() || password2.isNullOrEmpty()) {
                Toast.makeText(requireContext(), "Пожалуйста, заполните все поля", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            if (password1 != password2) {
                Toast.makeText(requireContext(), "Пароли не совпадают", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            performRegister(login, password1)
        }

        loginButton.setOnClickListener {
            // Переход на экран логина
            parentFragmentManager.beginTransaction()
                .replace(R.id.contentContainer, LoginFragment())
                .addToBackStack(null)
                .setTransition(FragmentTransaction.TRANSIT_FRAGMENT_OPEN)
                .commit()
        }

        return view
    }

    private fun performRegister(login: String, password: String) {
        lifecycleScope.launch {
            try {
                val response = ApiClient.apiService.registerUser(
                    RegisterRequest(login, password)
                )

                if (response.isSuccessful) {
                    val body = response.body()
                    if (body != null) {
                        saveUserToPreferences(body.id, body.token)
                        (requireActivity() as MainActivity).showMainScreen()
                    }
                } else {
                    Toast.makeText(requireContext(), "Ошибка: ${response.message()}", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(requireContext(), "Ошибка: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun saveUserToPreferences(userId: Int, token: String) {
        val sharedPref = requireContext().getSharedPreferences("UserPrefs", AppCompatActivity.MODE_PRIVATE)
        sharedPref.edit()
            .putInt("currentUserId", userId)
            .putString("authToken", token)
            .apply()
    }

    override fun onResume() {
        super.onResume()
        // Убираем навигацию и мини-плеер на экране регистрации
        (requireActivity() as MainActivity).hideMiniPlayer()
    }
}
