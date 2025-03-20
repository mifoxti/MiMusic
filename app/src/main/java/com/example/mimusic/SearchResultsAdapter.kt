package com.example.mimusic

import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide

class SearchResultsAdapter(private var songs: List<SongEl>) :
    RecyclerView.Adapter<SearchResultsAdapter.SongViewHolder>() {

    class SongViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val songTitle: TextView = view.findViewById(R.id.gallerytext)
        val songImage: ImageView = view.findViewById(R.id.galleryposter)
        val loveButton: Button = view.findViewById(R.id.galleryBtnLove)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): SongViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_song, parent, false)
        return SongViewHolder(view)
    }

    override fun onBindViewHolder(holder: SongViewHolder, position: Int) {
        val song = songs[position]
        holder.songTitle.text = song.title
        Log.d("SearchResultsAdapter", "Loading image from URL: ${song.header_image_url}") // Логируем URL
        Glide.with(holder.itemView.context)
            .load(song.header_image_url)
//            .placeholder(R.drawable.music_image) // Заглушка, если изображение не загружено
//            .error(R.drawable.music_image) // Изображение при ошибке загрузки
            .into(holder.songImage)
    }

    override fun getItemCount() = songs.size

    fun updateData(newSongs: List<SongEl>) {
        songs = newSongs
        notifyDataSetChanged()
    }
}
