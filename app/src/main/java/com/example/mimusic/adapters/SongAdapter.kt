package com.example.mimusic.adapters

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.datas.Song
import com.example.mimusic.services.UserManager
import com.google.android.material.button.MaterialButton
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

        // Обновляем состояние кнопки при первом отображении
        updateLikeButton(holder.loveButton, UserManager.currentUser?.likedSongs?.contains(song.filePath) ?: false)

        holder.loveButton.setOnClickListener {
            val currentUser = UserManager.currentUser
            if (currentUser != null) {
                val isCurrentlyLiked = currentUser.likedSongs.contains(song.filePath)

                if (isCurrentlyLiked) {
                    UserManager.removeLikedSong(song.filePath)
                    updateLikeButton(holder.loveButton, false)
                } else {
                    UserManager.addLikedSong(song.filePath)
                    updateLikeButton(holder.loveButton, true)
                }
            }
        }
    }

    private fun updateLikeButton(button: Button, isLiked: Boolean) {
        val iconRes = if (isLiked) R.drawable.ic_heart_filled else R.drawable.ic_heart
        if (button is MaterialButton) {
            button.icon = ContextCompat.getDrawable(button.context, iconRes)
        }
    }
    override fun getItemCount(): Int = songs.size

    class SongViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val poster: ShapeableImageView = itemView.findViewById(R.id.galleryposter)
        private val title: TextView = itemView.findViewById(R.id.gallerytext)
        val loveButton: Button = itemView.findViewById(R.id.galleryBtnLove)

        fun bind(song: Song) {
            title.text = song.title
            if (song.coverArt != null) {
                poster.setImageBitmap(song.coverArt)
            } else {
                poster.setImageResource(R.drawable.music_image)
            }
        }
    }
}