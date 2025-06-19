package com.example.mimusic.adapters

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.datas.Song
import com.google.android.material.button.MaterialButton
import com.google.android.material.imageview.ShapeableImageView

class SongAdapter(
    private var songs: List<Song>,
    private val onItemClick: (Song) -> Unit,
    private val onLikeClick: (Song, Int) -> Unit
) : RecyclerView.Adapter<SongAdapter.SongViewHolder>() {

    private val likedStates = mutableMapOf<Int, Boolean>()

    fun updateSongs(newSongs: List<Song>) {
        songs = newSongs
        likedStates.clear()
        notifyDataSetChanged()
    }

    fun setLikeStateAt(position: Int, isLiked: Boolean) {
        likedStates[position] = isLiked
        notifyItemChanged(position)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): SongViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_song, parent, false)
        return SongViewHolder(view)
    }

    override fun onBindViewHolder(holder: SongViewHolder, position: Int) {
        val song = songs[position]
        val isLiked = likedStates[position] ?: false
        holder.bind(song, isLiked)
        holder.itemView.setOnClickListener { onItemClick(song) }
        holder.loveButton.setOnClickListener {
            onLikeClick(song, position)
        }
    }

    override fun getItemCount(): Int = songs.size

    class SongViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val poster: ShapeableImageView = itemView.findViewById(R.id.galleryposter)
        private val title: TextView = itemView.findViewById(R.id.gallerytext)
        val loveButton: MaterialButton = itemView.findViewById(R.id.galleryBtnLove)

        fun bind(song: Song, isLiked: Boolean) {
            title.text = song.title
            if (song.coverArt != null) {
                poster.setImageBitmap(song.coverArt)
            } else {
                poster.setImageResource(R.drawable.music_image)
            }
            loveButton.setIconResource(
                if (isLiked) R.drawable.ic_heart_filled else R.drawable.ic_heart
            )
        }
    }
}
