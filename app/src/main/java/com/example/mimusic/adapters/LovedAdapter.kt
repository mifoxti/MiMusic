package com.example.mimusic.adapters

import android.graphics.BitmapFactory
import android.util.Base64
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.serverSide.LovedRemote
import com.google.android.material.button.MaterialButton
import com.google.android.material.imageview.ShapeableImageView


class LovedAdapter(
    private var songs: List<LovedRemote>,
    private val onItemClick: (LovedRemote) -> Unit,
    private val onLikeClick: (LovedRemote, Int) -> Unit,
) : RecyclerView.Adapter<LovedAdapter.LovedViewHolder>() {

    fun updateData(newSongs: List<LovedRemote>) {
        songs = newSongs
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): LovedViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_song, parent, false)
        return LovedViewHolder(view)
    }

    override fun onBindViewHolder(holder: LovedViewHolder, position: Int) {
        val song = songs[position]
        holder.bind(song)
        holder.itemView.setOnClickListener {
            onItemClick(song)
        }
        holder.loveButton.setOnClickListener {
            onLikeClick(song, position)
        }
    }

    override fun getItemCount(): Int = songs.size

    class LovedViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val poster: ShapeableImageView = view.findViewById(R.id.galleryposter)
        private val title: TextView = view.findViewById(R.id.gallerytext)
        val loveButton: MaterialButton = view.findViewById(R.id.galleryBtnLove)

        fun bind(song: LovedRemote) {
            title.text = song.title
            if (song.coverArt != null) {
                val decoded = Base64.decode(song.coverArt, Base64.DEFAULT)
                val bitmap = BitmapFactory.decodeByteArray(decoded, 0, decoded.size)
                poster.setImageBitmap(bitmap)
            } else {
                poster.setImageResource(R.drawable.music_image)
            }

            loveButton.setIconResource(R.drawable.ic_heart_filled)
        }
    }
}

