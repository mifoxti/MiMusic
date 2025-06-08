package com.example.mimusic.utils

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.util.Log
import com.example.mimusic.R
import com.example.mimusic.datas.Song

object Mp3MetadataExtractor {
    fun extractMetadata(context: Context, resourceId: Int, fileName: String): Song? {
        val retriever = MediaMetadataRetriever()
        try {
            val fileDescriptor = context.resources.openRawResourceFd(resourceId)
            retriever.setDataSource(
                fileDescriptor.fileDescriptor,
                fileDescriptor.startOffset,
                fileDescriptor.length
            )
            fileDescriptor.close()

            return Song(
                title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                    ?: fileName.replace("_", " ").replace(".mp3", ""),
                filePath = "android.resource://${context.packageName}/$resourceId",
                artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                    ?: "Unknown Artist",
                coverArt = retriever.embeddedPicture?.let {
                    BitmapFactory.decodeByteArray(it, 0, it.size)
                },
                duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull() ?: 0L,
                album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
                    ?: "Unknown Album",
                fileName = fileName,
                year = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR),
                genre = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_GENRE),
                trackNumber = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER)
                    ?.toIntOrNull(),
                bitrate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                    ?.toIntOrNull(),
                sampleRate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_SAMPLERATE)
                    ?.toIntOrNull()
            )
        } catch (e: Exception) {
            Log.e("Mp3MetadataExtractor", "Error extracting metadata", e)
            return null
        } finally {
            retriever.release()
        }
    }

    fun getRawSongs(context: Context): List<Song> {
        val songs = mutableListOf<Song>()
        val resources = context.resources
        val field = R.raw::class.java
        val rawFiles = field.declaredFields

        for (file in rawFiles) {
            try {
                val fileName = file.name
                val resourceId = resources.getIdentifier(fileName, "raw", context.packageName)
                if (resourceId != 0) {
                    val song = extractMetadata(context, resourceId, fileName)
                    if (song != null) {
                        songs.add(song)
                        Log.d("Mp3MetadataExtractor", "Found song: ${song.title}")
                    }
                }
            } catch (e: Exception) {
                Log.e("Mp3MetadataExtractor", "Error processing file: ${file.name}", e)
            }
        }

        return songs
    }
}