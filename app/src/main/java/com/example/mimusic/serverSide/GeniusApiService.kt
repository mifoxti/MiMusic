package com.example.mimusic.serverSide

import retrofit2.Call
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.Query

interface GeniusApiService {
    @GET("search")
    fun searchSongs(
        @Header("Authorization") token: String,
        @Query("q") query: String
    ): Call<GeniusResponse>
}