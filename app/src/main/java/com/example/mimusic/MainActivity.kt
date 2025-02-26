package com.example.mimusic

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

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