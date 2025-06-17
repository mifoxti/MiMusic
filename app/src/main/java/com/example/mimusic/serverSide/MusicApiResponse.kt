package com.example.mimusic.serverSide

data class TrackResponse(
    val id: Int,
    val title: String,
    val artist: String?,
    val duration: Int?,
    val cover: String?
)

data class LoginRespose(
    val token: String,
    val id: Int,
)

data class RegisterResponse (
    val token: String,
    val id: Int,
)

data class SearchRemote(
    val id: Int,
    val title: String,
    val artist: String?,
    val duration: Int?,
    val coverArt: String?,
)