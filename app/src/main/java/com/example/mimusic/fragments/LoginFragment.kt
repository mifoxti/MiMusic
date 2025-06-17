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
import com.example.mimusic.serverSide.LoginRequest
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.launch

class LoginFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_login, container, false)

        val loginBtn = view.findViewById<MaterialButton>(R.id.loginButton)
        val regBtn = view.findViewById<MaterialButton>(R.id.regBtn)

        loginBtn.setOnClickListener {
            val login = view.findViewById<TextInputEditText>(R.id.loginText)?.text?.toString()?.trim()
            val password = view.findViewById<TextInputEditText>(R.id.passwordText)?.text?.toString()

            if (login.isNullOrEmpty() || password.isNullOrEmpty()) {
                Toast.makeText(requireContext(), "Пожалуйста, заполните все поля", Toast.LENGTH_SHORT).show()
            } else {
                performLogin(login, password)
            }
        }

        regBtn.setOnClickListener {
            requireActivity()
                .supportFragmentManager
                .beginTransaction()
                .replace(R.id.contentContainer, RegisterFragment())
                .addToBackStack(null)
                .setTransition(FragmentTransaction.TRANSIT_FRAGMENT_OPEN)
                .commit()
        }

        return view
    }

    private fun performLogin(login: String, password: String) {
        lifecycleScope.launch {
            try {
                val response = ApiClient.apiService.loginUser(
                    LoginRequest(login, password)
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
        (requireActivity() as MainActivity).hideMiniPlayer()
    }
}
