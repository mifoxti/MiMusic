package com.example.mimusic

import android.graphics.Bitmap

data class Song(
    val title: String,
    val filePath: String,
    val coverArt: Bitmap? = null // Обложка
)