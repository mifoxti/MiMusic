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

class MainActivity : AppCompatActivity() {
    private lateinit var miniPlayerHandler: MiniPlayerHandler
    private lateinit var miniPlayerView: View

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        applyTheme()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Инициализация мини-плеера
        miniPlayerView = findViewById(R.id.miniPlayerContainer)
        miniPlayerHandler = MiniPlayerHandler(this, miniPlayerView)

        // Показываем или скрываем мини-плеер в зависимости от состояния MusicPlayer
        updateMiniPlayerVisibility()

        // Подписываемся на уведомления о начале воспроизведения
        MusicPlayer.addPlaybackStateListener {
            updateMiniPlayerVisibility()
        }

        // Загружаем начальный фрагмент
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(R.id.contentContainer, FragmentMain())
                .commit()

            // Добавляем навигационный бар
            supportFragmentManager.beginTransaction()
                .replace(R.id.bottomNavigationContainer, BottomNavigationFragment())
                .commit()
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

    private fun updateMiniPlayerVisibility() {
        if (MusicPlayer.getCurrentSong() != null && MusicPlayer.isPlaying()) {
            miniPlayerView.visibility = View.VISIBLE
        } else {
            miniPlayerView.visibility = View.GONE
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        miniPlayerHandler.release() // Останавливаем обновление прогресса

    }

    override fun onBackPressed() {
        // Проверяем, есть ли фрагменты в back stack
        if (supportFragmentManager.backStackEntryCount > 0) {
            // Возвращаемся на предыдущий фрагмент
            supportFragmentManager.popBackStack()
        } else {
            // Если back stack пуст, завершаем Activity
            super.onBackPressed()
        }
    }
}