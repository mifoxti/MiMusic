package com.example.mimusic

import android.os.Bundle
import android.view.View
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.example.mimusic.fragments.BottomNavigationFragment
import com.example.mimusic.fragments.FragmentMain
import com.example.mimusic.services.MiniPlayerHandler
import com.example.mimusic.services.MusicPlayer
import androidx.appcompat.app.AppCompatDelegate
import com.example.mimusic.fragments.RegisterFragment

class MainActivity : AppCompatActivity() {
    private lateinit var miniPlayerHandler: MiniPlayerHandler
    private lateinit var miniPlayerView: View

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        applyTheme()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        miniPlayerView = findViewById(R.id.miniPlayerContainer)
        miniPlayerHandler = MiniPlayerHandler(this, miniPlayerView)

        MusicPlayer.addPlaybackStateListener {
            updateMiniPlayerVisibility()
        }

        if (savedInstanceState == null) {
            val sharedPref = getSharedPreferences("UserPrefs", MODE_PRIVATE)
            val userId = sharedPref.getInt("currentUserId", -1)

            if (userId != -1) {
                showMainScreen()
            } else {
                supportFragmentManager.beginTransaction()
                    .replace(R.id.contentContainer, RegisterFragment())
                    .commit()
                hideMiniPlayer()
            }
        }
    }

    private fun applyTheme() {
        val sharedPref = getSharedPreferences("AppTheme", MODE_PRIVATE)
        val isDarkTheme = sharedPref.getBoolean("isDarkTheme", false)

        if (isDarkTheme) {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
        } else {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
        }
    }

    fun showMainScreen() {
        supportFragmentManager.beginTransaction()
            .replace(R.id.contentContainer, FragmentMain())
            .commit()

        supportFragmentManager.beginTransaction()
            .replace(R.id.bottomNavigationContainer, BottomNavigationFragment())
            .commit()

        updateMiniPlayerVisibility()
    }

    private fun updateMiniPlayerVisibility() {
        if (MusicPlayer.getCurrentSong() != null) {
            miniPlayerView.visibility = View.VISIBLE
        } else {
            miniPlayerView.visibility = View.GONE
        }
    }

    fun hideMiniPlayer() {
        miniPlayerView.visibility = View.GONE
    }

    override fun onDestroy() {
        super.onDestroy()
        miniPlayerHandler.release()
    }

    override fun onBackPressed() {
        if (supportFragmentManager.backStackEntryCount > 0) {
            supportFragmentManager.popBackStack()
        } else {
            super.onBackPressed()
        }
    }
}
