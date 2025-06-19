package com.example.mimusic.serverSide

import com.example.mimusic.datas.Song
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    @GET("/tracks")
    suspend fun getAllTracks(): Response<List<TrackResponse>>

    @GET("/tracks/{id}/stream")
    suspend fun streamTrack(
        @Path("id") id: Int
    ): Response<ResponseBody>

    @POST("/register")
    suspend fun registerUser(
        @Body body: RegisterRequest
    ): Response<RegisterResponse>

    @POST("/login")
    suspend fun loginUser(
        @Body body: LoginRequest
    ): Response<LoginResponse>

    @POST("/tracks/{trackId}/like")
    suspend fun toggleLike(
        @Path("trackId") trackId: Int,
        @Body request: ToggleLikeRequest
    ): Response<ToggleLikeResponse>

    @GET("tracks/{trackId}/like")
    suspend fun isTrackLiked(
        @Path("trackId") trackId: Int,
        @Query("userId") userId: Int
    ): Response<ToggleLikeResponse>

    @GET("/search")
    suspend fun searchTracks(
        @Query("q") query: String,
        @Query("userId") userId: Int
    ): Response<List<SearchRemote>>

    @GET("/users/{id}/thought")
    suspend fun getThought(@Path("id") userId: Int): Response<Map<String, String>>

    @POST("/users/{id}/thought")
    suspend fun updateThought(
        @Path("id") userId: Int,
        @Query("th") newThought: String
    ): Response<Map<String, String>>

    @GET("/users/{id}/loved")
    suspend fun getLikedTracks(
        @Path("id") userId: Int)
    : Response<List<LovedRemote>>

    @GET("/artist")
    suspend fun getArtistInfo(
        @Query("name") name: String,
        @Query("userId") userId: Int
    ): Response<ArtistRemote>
    // Примеры запросов больше не нужны, я закончил, Я СВОБООООДЕЕЕЕН (пока не настанет время диплома)
}