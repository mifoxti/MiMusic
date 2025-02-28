package com.example.mimusic

import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    private lateinit var miniPlayerHandler: MiniPlayerHandler
    private lateinit var miniPlayerView: View

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Инициализация мини-плеера
        miniPlayerView = findViewById(R.id.miniPlayerContainer)
        miniPlayerHandler = MiniPlayerHandler(this, miniPlayerView)

        // Показываем или скрываем мини-плеер в зависимости от состояния MusicPlayer
        updateMiniPlayerVisibility()

        // Подписываемся на уведомления о начале воспроизведения
        MusicPlayer.setOnPlaybackStartedListener {
            updateMiniPlayerVisibility()
        }

        // Загружаем начальный фрагмент (например, FragmentMain)
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