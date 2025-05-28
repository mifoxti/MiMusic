package com.example.mimusic.fragments

import android.os.Bundle
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.fragment.app.FragmentManager
import com.example.mimusic.R
import com.example.mimusic.fragments.EmptyFragment
import com.example.mimusic.fragments.RegisterFragment
import com.google.android.material.button.MaterialButton
import com.google.android.material.imageview.ShapeableImageView

class ProfileFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_profile, container, false)

        // Находим кнопку настроек
        val settingsButton = view.findViewById<MaterialButton>(R.id.settingsButton)
        // Находим кнопку "Мысли"
        val thoughtsButton = view.findViewById<MaterialButton>(R.id.thoughtsBtn)

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
            clearFragmentsAndOpenRegister()
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
}