package com.example.mimusic.datas

import android.graphics.Bitmap
import android.os.Parcel
import android.os.Parcelable

data class Song(
    val id: Int? = null,
    val title: String,
    val filePath: String,
    val artist: String,
    val coverArt: Bitmap? = null,
    val duration: Long = 0L,
    val album: String = "",
    val fileName: String = "",
    val year: String? = null,
    val genre: String? = null,
    val trackNumber: Int? = null,
    val bitrate: Int? = null,
    val sampleRate: Int? = null
) : Parcelable {

    constructor(parcel: Parcel) : this(
        title = parcel.readString() ?: "",
        filePath = parcel.readString() ?: "",
        artist = parcel.readString() ?: "",
        coverArt = parcel.readParcelable(Bitmap::class.java.classLoader),
        duration = parcel.readLong(),
        album = parcel.readString() ?: "",
        fileName = parcel.readString() ?: "",
        year = parcel.readString(),
        genre = parcel.readString(),
        trackNumber = parcel.readValue(Int::class.java.classLoader) as? Int,
        bitrate = parcel.readValue(Int::class.java.classLoader) as? Int,
        sampleRate = parcel.readValue(Int::class.java.classLoader) as? Int
    )

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeString(title)
        parcel.writeString(filePath)
        parcel.writeString(artist)
        parcel.writeParcelable(coverArt, flags)
        parcel.writeLong(duration)
        parcel.writeString(album)
        parcel.writeString(fileName)
        parcel.writeString(year)
        parcel.writeString(genre)
        parcel.writeValue(trackNumber)
        parcel.writeValue(bitrate)
        parcel.writeValue(sampleRate)
    }

    override fun describeContents(): Int = 0

    companion object CREATOR : Parcelable.Creator<Song> {
        override fun createFromParcel(parcel: Parcel): Song {
            return Song(parcel)
        }

        override fun newArray(size: Int): Array<Song?> {
            return arrayOfNulls(size)
        }
    }

    // Форматированная длительность (mm:ss)
    fun formattedDuration(): String {
        val seconds = (duration / 1000) % 60
        val minutes = (duration / (1000 * 60)) % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    // Проверка наличия обложки
    fun hasCoverArt(): Boolean = coverArt != null
    fun toSongEl(): SongEl {
        return SongEl(
            id = this.hashCode(),
            title = this.title,
            artist = this.artist,
            coverArt = this.coverArt,
            isLoved = false
        )
    }
}