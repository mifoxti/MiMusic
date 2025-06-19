package com.example.mimusic.datas

import android.graphics.Bitmap
import android.os.Parcel
import android.os.Parcelable

data class Song(
    val title: String,
    val idOnServer: Int,
    val artist: String,
    val coverArt: Bitmap? = null
) : Parcelable {
    constructor(parcel: Parcel) : this(
        title = parcel.readString() ?: "",
        idOnServer = parcel.readInt() ?: 0,
        artist = parcel.readString() ?: "",
        coverArt = parcel.readParcelable(Bitmap::class.java.classLoader)
    )

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeString(title)
        parcel.writeInt(idOnServer)
        parcel.writeString(artist)
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