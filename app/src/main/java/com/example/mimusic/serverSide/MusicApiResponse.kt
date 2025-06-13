package com.example.mimusic.serverSide

data class TrackResponse(
    val id: Int,
    val title: String,
    val artist: String?,
    val duration: Int?,
    val cover: String?
)

