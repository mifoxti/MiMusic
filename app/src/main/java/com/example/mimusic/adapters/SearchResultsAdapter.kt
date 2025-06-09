package com.example.mimusic.adapters

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.example.mimusic.R
import com.example.mimusic.datas.SongEl

class SearchResultsAdapter(
    private var songs: List<SongEl>,
    private val onItemClick: (SongEl) -> Unit,
    private val onLoveClick: (SongEl) -> Unit
) : RecyclerView.Adapter<SearchResultsAdapter.SongViewHolder>() {

    class SongViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val songTitle: TextView = view.findViewById(R.id.gallerytext)
        val songImage: com.google.android.material.imageview.ShapeableImageView = view.findViewById(R.id.galleryposter)
        val loveButton: com.google.android.material.button.MaterialButton = view.findViewById(R.id.galleryBtnLove)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): SongViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_song, parent, false)
        return SongViewHolder(view)
    }

    override fun onBindViewHolder(holder: SongViewHolder, position: Int) {
        val song = songs[position]

        holder.songTitle.text = song.title

        // Загрузка изображения с Glide
        Glide.with(holder.itemView.context)
            .load(song.coverArt ?: R.drawable.music_image)
            .placeholder(R.drawable.music_image)
            .error(R.drawable.music_image)
            .into(holder.songImage)

        // Установка иконки для кнопки "лайка"
        holder.loveButton.icon = ContextCompat.getDrawable(
            holder.itemView.context,
            if (song.isLoved) R.drawable.ic_heart_filled
            else R.drawable.ic_heart
        )

        holder.itemView.setOnClickListener { onItemClick(song) }
        holder.loveButton.setOnClickListener { onLoveClick(song) }
    }

    override fun getItemCount() = songs.size

    fun updateData(newSongs: List<SongEl>) {
        songs = newSongs
        notifyDataSetChanged()
    }
    fun updateSongLikeStatus(songId: Int, isLiked: Boolean) {
        songs = songs.map { song ->
            if (song.id == songId) song.copy(isLoved = isLiked) else song
        }
        notifyDataSetChanged()
    }
}