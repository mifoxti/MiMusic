package com.example.mimusic.fragments

import android.content.Context
import android.os.Bundle
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatDelegate
import androidx.fragment.app.FragmentManager
import com.example.mimusic.MainActivity
import com.example.mimusic.R
import com.example.mimusic.fragments.EmptyFragment
import com.example.mimusic.fragments.RegisterFragment
import com.example.mimusic.services.UserManager
import com.google.android.material.button.MaterialButton
import com.google.android.material.imageview.ShapeableImageView

class ProfileFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        if (UserManager.currentUser == null) {
            // Перенаправляем на экран входа
            parentFragmentManager.beginTransaction()
                .replace(R.id.contentContainer, LoginFragment())
                .commit()
            return null
        }
        val view = inflater.inflate(R.layout.fragment_profile, container, false)

        // Находим кнопку настроек
        val settingsButton = view.findViewById<MaterialButton>(R.id.settingsButton)
        // Находим кнопку "Мысли"
        val thoughtsButton = view.findViewById<MaterialButton>(R.id.thoughtsBtn)
        // Находим кнопку переключения темы
        val themeToggleButton = view.findViewById<MaterialButton>(R.id.themeToggleButton)

        // Обработчик нажатия на кнопку переключения темы (был вырезан в прошлой версии, т.к. вызывал проблемы)
        themeToggleButton.setOnClickListener {
            toggleTheme()
        }


        val lovedImage = view.findViewById<ShapeableImageView>(R.id.loved_image)
        val lovedText = view.findViewById<TextView>(R.id.text_loved)

        val lovedClickListener = View.OnClickListener {
            parentFragmentManager.beginTransaction()
                .replace(R.id.contentContainer, LovedFragment())
                .addToBackStack("loved_fragment")
                .commit()
        }

        lovedImage.setOnClickListener(lovedClickListener)
        lovedText.setOnClickListener(lovedClickListener)

        // Обработчик нажатия на кнопку настроек
        settingsButton.setOnClickListener {
            UserManager.logout()
            (requireActivity() as MainActivity).showLoginScreen()
        }

        // Обработчик нажатия на кнопку "Мысли"
        thoughtsButton.setOnClickListener {
            openThoughtsFragment()
        }

        return view
    }

    private fun clearFragmentsAndOpenRegister() {
        val fragmentManager: FragmentManager = parentFragmentManager
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

    private fun openThoughtsFragment() {
        parentFragmentManager.beginTransaction()
            .replace(R.id.contentContainer, ThoughtsFragment())
            .addToBackStack("thoughts_fragment") // Добавляем в back stack для возврата
            .commit()
    }

    private fun toggleTheme() {
        val sharedPref = requireContext().getSharedPreferences("AppTheme", Context.MODE_PRIVATE)
        val isDarkTheme = sharedPref.getBoolean("isDarkTheme", false)
        val newTheme = !isDarkTheme

        sharedPref.edit().putBoolean("isDarkTheme", newTheme).apply()

        // Применяем новую тему
        if (newTheme) {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
        } else {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
        }


    }
}