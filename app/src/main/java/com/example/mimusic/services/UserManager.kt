package com.example.mimusic.services

import android.content.Context
import android.util.Log
import androidx.core.content.edit
import com.example.mimusic.datas.User
import org.json.JSONArray
import org.json.JSONObject

object UserManager {
    private val _users = mutableListOf<User>()
    var currentUser: User? = null
        private set

    private lateinit var sharedPreferences: android.content.SharedPreferences

    // Инициализация с контекстом
    fun init(context: Context) {
        sharedPreferences = context.getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
        restoreCurrentUser() // Теперь безопасно
        loadUsers()
    }

    // Загрузка всех пользователей из SharedPreferences
    private fun loadUsers() {
        val usersJson = sharedPreferences.getString("users", null)
        if (usersJson != null) {
            val jsonArray = JSONArray(usersJson)
            for (i in 0 until jsonArray.length()) {
                val userJson = jsonArray.getJSONObject(i)
                val login = userJson.getString("login")
                val password = userJson.getString("password")

                val user = User(login, password)

                // Восстанавливаем понравившиеся песни
                val likedSongsJson = sharedPreferences.getString("liked_songs_${login}", null)
                if (likedSongsJson != null) {
                    val songsArray = JSONArray(likedSongsJson)
                    for (j in 0 until songsArray.length()) {
                        user.likedSongs.add(songsArray.getString(j))
                    }
                }

                _users.add(user)
            }
        }
    }

    // Сохраняем список пользователей в SharedPreferences
    private fun saveUsers() {
        val jsonArray = JSONArray()
        for (user in _users) {
            val userJson = JSONObject()
            userJson.put("login", user.login)
            userJson.put("password", user.password)
            jsonArray.put(userJson)
        }

        sharedPreferences.edit {
            putString("users", jsonArray.toString())
        }
    }

    // Восстановление текущего пользователя
    private fun restoreCurrentUser() {
        val login = sharedPreferences.getString("current_user_login", null)
        if (login != null) {
            currentUser = _users.find { it.login == login }
        }
    }

    // Регистрация нового пользователя
    fun register(login: String, password: String): Boolean {
        if (_users.any { it.login == login }) return false

        val newUser = User(login, password)
        _users.add(newUser)
        currentUser = newUser
        saveUsers()
        return true
    }

    // Вход пользователя
    fun login(login: String, password: String): Boolean {
        val user = _users.find { it.login == login && it.password == password } ?: return false
        currentUser = user

        // Сохраняем текущего пользователя
        sharedPreferences.edit {
            putString("current_user_login", login)
        }

        return true
    }

    // Выход
    fun logout() {
        currentUser = null
        sharedPreferences.edit {
            remove("current_user_login")
        }
    }

    fun addLikedSong(filePath: String) {
        currentUser?.let { user ->
            if (!user.likedSongs.contains(filePath)) {
                user.likedSongs.add(filePath)
                saveLikedSongs(user)
            }
        }
    }

    fun removeLikedSong(filePath: String) {
        currentUser?.let { user ->
            if (user.likedSongs.contains(filePath)) {
                user.likedSongs.remove(filePath)
                saveLikedSongs(user)
            }
        }
    }

    fun isSongLiked(filePath: String): Boolean {
        return currentUser?.likedSongs?.contains(filePath) ?: false
    }

    // Сохранение списка понравившихся песен
    private fun saveLikedSongs(user: User) {
        val songsArray = JSONArray(user.likedSongs)
        sharedPreferences.edit {
            putString("liked_songs_${user.login}", songsArray.toString())
        }
    }
}