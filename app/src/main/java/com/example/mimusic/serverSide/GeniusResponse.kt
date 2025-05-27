package com.example.mimusic.serverSide

data class GeniusResponse(
    val response: HitsWrapper
)

data class HitsWrapper(
    val hits: List<Hit>
)

data class Hit(
    val result: SongEl
)

data class SongEl(
    val id: Int,
    val title: String,
    val artistNames: String,
    val header_image_url: String
)
