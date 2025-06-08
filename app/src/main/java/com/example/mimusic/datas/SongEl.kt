package com.example.mimusic.datas

import android.graphics.Bitmap
import android.os.Parcel
import android.os.Parcelable

data class SongEl(
    val id: Int,
    val title: String,
    val artist: String,
    val coverArt: Bitmap? = null,
    var isLoved: Boolean = false
) : Parcelable {

    constructor(parcel: Parcel) : this(
        id = parcel.readInt(),
        title = parcel.readString() ?: "",
        artist = parcel.readString() ?: "",
        coverArt = parcel.readParcelable(Bitmap::class.java.classLoader),
        isLoved = parcel.readByte() != 0.toByte()
    )

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeInt(id)
        parcel.writeString(title)
        parcel.writeString(artist)
        parcel.writeParcelable(coverArt, flags)
        parcel.writeByte(if (isLoved) 1 else 0)
    }

    override fun describeContents(): Int {
        return 0 // Стандартная реализация для большинства случаев
    }

    companion object CREATOR : Parcelable.Creator<SongEl> {
        override fun createFromParcel(parcel: Parcel): SongEl {
            return SongEl(parcel)
        }

        override fun newArray(size: Int): Array<SongEl?> {
            return arrayOfNulls(size)
        }
    }
}