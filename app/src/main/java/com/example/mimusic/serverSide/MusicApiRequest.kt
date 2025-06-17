package com.example.mimusic.serverSide

data class RegisterRequest(
    val login: String,
    val password: String,
)

data class LoginRequest(
    val login: String,
    val password: String
)
