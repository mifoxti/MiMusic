package com.example.mimusic.adapters

import android.graphics.BitmapFactory
import android.util.Base64
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.example.mimusic.R
import com.example.mimusic.serverSide.SearchRemote
import com.google.android.material.button.MaterialButton
import com.google.android.material.imageview.ShapeableImageView

class SearchResultsAdapter(
    var songs: List<SearchRemote>,
    private val onLikeClick: (SearchRemote, Int) -> Unit,
    private val onItemClick: (SearchRemote) -> Unit,
) : RecyclerView.Adapter<SearchResultsAdapter.SongViewHolder>() {

    fun updateData(newSongs: List<SearchRemote>) {
        songs = newSongs
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): SongViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_song, parent, false)
        return SongViewHolder(view)
    }

    override fun onBindViewHolder(holder: SongViewHolder, position: Int) {
        val song = songs[position]
        holder.bind(song)

        holder.loveButton.setOnClickListener {
            onLikeClick(song, position)
        }

        holder.itemView.setOnClickListener {
            onItemClick(song)
        }
    }

    override fun getItemCount() = songs.size

    class SongViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val poster = view.findViewById<ShapeableImageView>(R.id.galleryposter)
        private val title = view.findViewById<TextView>(R.id.gallerytext)
        val loveButton: View = view.findViewById(R.id.galleryBtnLove)

        fun bind(song: SearchRemote) {
            title.text = song.title
            if (song.coverArt != null) {
                val decoded = Base64.decode(song.coverArt, Base64.DEFAULT)
                val bitmap = BitmapFactory.decodeByteArray(decoded, 0, decoded.size)
                poster.setImageBitmap(bitmap)
            } else {
                poster.setImageResource(R.drawable.music_image)
            }

            val iconRes = if (song.isLiked == true) R.drawable.ic_heart_filled else R.drawable.ic_heart
            (loveButton as? MaterialButton)?.setIconResource(iconRes)
        }
    }
}
