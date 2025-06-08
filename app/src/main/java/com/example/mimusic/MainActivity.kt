package com.example.mimusic

import android.os.Bundle
import android.util.Log
import android.view.View
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.example.mimusic.fragments.BottomNavigationFragment
import com.example.mimusic.fragments.FragmentMain
import com.example.mimusic.services.MiniPlayerHandler
import com.example.mimusic.services.MusicPlayer
import androidx.appcompat.app.AppCompatDelegate
import androidx.fragment.app.FragmentManager
import com.example.mimusic.fragments.LoginFragment
import com.example.mimusic.fragments.RegisterFragment
import com.example.mimusic.services.UserManager

class MainActivity : AppCompatActivity() {
    private lateinit var miniPlayerHandler: MiniPlayerHandler
    private lateinit var miniPlayerView: View

    private val songChangedListener = {
        updateMiniPlayerVisibility()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        applyTheme()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        UserManager.init(applicationContext)
        // Инициализация мини-плеера
        miniPlayerView = findViewById(R.id.miniPlayerContainer)
        miniPlayerHandler = MiniPlayerHandler(this, miniPlayerView)
        Log.d("MainActivity", "UserManager.currentUser = ${UserManager.currentUser}")

        MusicPlayer.addSongChangedListener(songChangedListener)
        updateMiniPlayerVisibility()


        if (savedInstanceState == null) {
            if (UserManager.currentUser == null) {
                supportFragmentManager.beginTransaction()
                    .add(R.id.contentContainer, LoginFragment())
                    .addToBackStack("login")
                    .commit()
            } else {
                onLoginSuccess()
            }
        }
    }

    private fun applyTheme() {
        val sharedPref = getSharedPreferences("AppTheme", MODE_PRIVATE)
        val isDarkTheme = sharedPref.getBoolean("isDarkTheme", false)
        AppCompatDelegate.setDefaultNightMode(
            if (isDarkTheme) AppCompatDelegate.MODE_NIGHT_YES
            else AppCompatDelegate.MODE_NIGHT_NO
        )
    }

    private fun updateMiniPlayerVisibility() {
        miniPlayerView.visibility =
            if (MusicPlayer.getCurrentSong() != null && MusicPlayer.isPlaying()) View.VISIBLE
            else View.GONE
    }

    override fun onDestroy() {
        super.onDestroy()
        MusicPlayer.removeSongChangedListener(songChangedListener)
        miniPlayerHandler.release()
    }

    override fun onBackPressed() {
        if (supportFragmentManager.backStackEntryCount > 0) {
            supportFragmentManager.popBackStack()
        } else {
            super.onBackPressed()
        }
    }

    fun showLoginScreen() {
        findViewById<View>(R.id.bottomNavigationContainer).visibility = View.GONE
        miniPlayerView.visibility = View.GONE

        supportFragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)

        supportFragmentManager.beginTransaction()
            .replace(R.id.contentContainer, LoginFragment())
            .addToBackStack("login")
            .commit()
    }

    fun showRegisterScreen() {
        findViewById<View>(R.id.bottomNavigationContainer).visibility = View.GONE
        miniPlayerView.visibility = View.GONE

        supportFragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)

        supportFragmentManager.beginTransaction()
            .replace(R.id.contentContainer, RegisterFragment())
            .addToBackStack("register")
            .commit()
    }

    fun showMainScreen() {
        findViewById<View>(R.id.bottomNavigationContainer).visibility = View.VISIBLE
        miniPlayerView.visibility = View.GONE

        supportFragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)

        supportFragmentManager.beginTransaction()
            .replace(R.id.contentContainer, FragmentMain())
            .commit()

        supportFragmentManager.beginTransaction()
            .replace(R.id.bottomNavigationContainer, BottomNavigationFragment())
            .commit()
    }

    fun onLoginSuccess() {
        findViewById<View>(R.id.bottomNavigationContainer).visibility = View.VISIBLE
        supportFragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)

        supportFragmentManager.beginTransaction()
            .replace(R.id.contentContainer, FragmentMain())
            .commit()

        supportFragmentManager.beginTransaction()
            .replace(R.id.bottomNavigationContainer, BottomNavigationFragment())
            .commit()
    }
}