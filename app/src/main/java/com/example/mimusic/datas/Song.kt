package com.example.mimusic.datas

import android.graphics.Bitmap
import android.os.Parcel
import android.os.Parcelable

data class Song(
    val title: String,
    val filePath: String,
    val artist: String,
    val coverArt: Bitmap? = null
) : Parcelable {
    constructor(parcel: Parcel) : this(
        title = parcel.readString() ?: "",
        filePath = parcel.readString() ?: "",
        artist = parcel.readString() ?: "",  // Added artist field
        coverArt = parcel.readParcelable(Bitmap::class.java.classLoader)
    )

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeString(title)
        parcel.writeString(filePath)
        parcel.writeString(artist)  // Added artist field
        parcel.writeParcelable(coverArt, flags)
    }

    override fun describeContents(): Int {
        return 0
    }

    companion object CREATOR : Parcelable.Creator<Song> {
        override fun createFromParcel(parcel: Parcel): Song {
            return Song(parcel)
        }

        override fun newArray(size: Int): Array<Song?> {
            return arrayOfNulls(size)
        }
    }
}