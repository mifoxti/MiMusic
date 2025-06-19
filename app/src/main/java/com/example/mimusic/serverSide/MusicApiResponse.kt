package com.example.mimusic.serverSide

data class TrackResponse(
    val id: Int,
    val title: String,
    val artist: String?,
    val duration: Int?,
    val cover: String?
)

data class LoginResponse(
    val token: String,
    val id: Int,
)

data class RegisterResponse (
    val token: String,
    val id: Int,
)

data class SearchRemote(
    val id: Int,
    val title: String,
    val artist: String?,
    val duration: Int?,
    val coverArt: String?,
    val isLiked: Boolean?
)

data class ToggleLikeRequest(val userId: Int)

data class ToggleLikeResponse(
    val status: Boolean,
)

data class LovedRemote(
    val id: Int,
    val title: String,
    val artist: String?,
    val coverArt: String?,
)

data class ArtistRemote(
    val thoughts: String,
    val songs: List<ArtistTrackRemote>
)

data class ArtistTrackRemote(
    val id: Int,
    val title: String,
    val artist: String,
    val coverArt: String?,
    var isLiked: Boolean
)