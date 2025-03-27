package com.example.mimusic

import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AppCompatDelegate
import androidx.fragment.app.FragmentManager
import com.google.android.material.button.MaterialButton

class ProfileFragment : Fragment() {

    private lateinit var sharedPreferences: SharedPreferences

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_profile, container, false)

        sharedPreferences = requireContext().getSharedPreferences("settings", Context.MODE_PRIVATE)

        // Устанавливаем сохраненную тему при запуске
        val isDarkMode = sharedPreferences.getBoolean("dark_mode", false)
        setTheme(isDarkMode)

        // Кнопка переключения темы
        val themeToggleButton = view.findViewById<MaterialButton>(R.id.themeToggleButton)
        themeToggleButton.setOnClickListener {
            val newTheme = !sharedPreferences.getBoolean("dark_mode", false)
            sharedPreferences.edit().putBoolean("dark_mode", newTheme).apply()
            setTheme(newTheme)
        }

        // Кнопка настроек
        val settingsButton = view.findViewById<MaterialButton>(R.id.settingsButton)
        settingsButton.setOnClickListener {
            clearFragmentsAndOpenRegister()
        }

        return view
    }

    private fun setTheme(isDarkMode: Boolean) {
        val mode = if (isDarkMode) AppCompatDelegate.MODE_NIGHT_YES else AppCompatDelegate.MODE_NIGHT_NO
        AppCompatDelegate.setDefaultNightMode(mode)
    }

    private fun clearFragmentsAndOpenRegister() {
        val fragmentManager = parentFragmentManager
        fragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)

        fragmentManager.beginTransaction()
            .replace(R.id.contentContainer, RegisterFragment())
            .addToBackStack("register_fragment")
            .commit()

        fragmentManager.beginTransaction()
            .replace(R.id.bottomNavigationContainer, EmptyFragment())
            .addToBackStack("empty_fragment")
            .commit()
    }
}
