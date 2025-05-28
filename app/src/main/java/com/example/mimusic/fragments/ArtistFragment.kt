package com.example.mimusic.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.mimusic.R

class ArtistFragment : Fragment() {
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_artist, container, false)
    }

    companion object {
        private const val ARG_ARTIST_NAME = "artist_name"

        fun newInstance(artistName: String): ArtistFragment {
            val fragment = ArtistFragment()
            val args = Bundle()
            args.putString(ARG_ARTIST_NAME, artistName)
            fragment.arguments = args
            return fragment
        }
    }
}