package com.example.mimusic.adapters

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.datas.Song
import com.google.android.material.imageview.ShapeableImageView

class SongAdapter(
    private val songs: List<Song>,
    private val onItemClick: (Song) -> Unit
) : RecyclerView.Adapter<SongAdapter.SongViewHolder>() {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): SongViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_song, parent, false)
        return SongViewHolder(view)
    }

    override fun onBindViewHolder(holder: SongViewHolder, position: Int) {
        val song = songs[position]
        holder.bind(song)
        holder.itemView.setOnClickListener { onItemClick(song) }
    }

    override fun getItemCount(): Int = songs.size

    class SongViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val poster: ShapeableImageView = itemView.findViewById(R.id.galleryposter)
        private val title: TextView = itemView.findViewById(R.id.gallerytext)

        fun bind(song: Song) {
            title.text = song.title
            if (song.coverArt != null) {
                poster.setImageBitmap(song.coverArt)
            } else {
                poster.setImageResource(R.drawable.music_image) // Обложка по умолчанию
            }
        }
    }
}