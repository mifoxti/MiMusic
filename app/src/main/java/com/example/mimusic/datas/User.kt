package com.example.mimusic.datas


data class User(
    val login: String,
    val password: String,
    val likedSongs: MutableList<String> = mutableListOf()
)