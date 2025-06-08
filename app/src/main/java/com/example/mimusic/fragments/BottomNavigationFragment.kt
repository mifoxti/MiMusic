package com.example.mimusic.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.mimusic.fragments.ProfileFragment
import com.example.mimusic.R
import com.example.mimusic.SearchFragment
import com.example.mimusic.services.UserManager
import com.google.android.material.bottomnavigation.BottomNavigationView

class BottomNavigationFragment : Fragment() {

    private var currentFragment: Fragment? = null

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_bottom_navigation, container, false)

        val bottomNavigationView = view.findViewById<BottomNavigationView>(R.id.bottomNavigationView)
        bottomNavigationView.setOnNavigationItemSelectedListener { item ->
            when (item.itemId) {
                R.id.item_1 -> {
                    replaceFragment(FragmentMain())
                    true
                }
                R.id.item_2 -> {
                    replaceFragment(SearchFragment())
                    true
                }
                R.id.item_3 -> {
                    replaceFragment(ProfileFragment())
                    true
                }
                else -> false
            }
        }


        if (savedInstanceState == null) {
            replaceFragment(FragmentMain())
        }

        return view
    }

    private fun replaceFragment(fragment: Fragment) {
        val fragmentManager = parentFragmentManager
        val fragmentTransaction = fragmentManager.beginTransaction()

        // Не добавляем в back stack для основных экранов
        fragmentTransaction.replace(R.id.contentContainer, fragment)

        // Для ProfileFragment проверяем авторизацию
        if (fragment is ProfileFragment && UserManager.currentUser == null) {
            fragmentTransaction.replace(R.id.contentContainer, LoginFragment())
        }

        fragmentTransaction.commit()
        currentFragment = fragment
    }

}