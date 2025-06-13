package com.example.mimusic.serverSide

import com.example.mimusic.datas.Song
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    @GET("/tracks")
    suspend fun getAllTracks(): Response<List<TrackResponse>>

    @GET("tracks/{id}/stream")
    suspend fun streamTrack(
        @Path("id") id: Int
    ): Response<ResponseBody>
//    // Пример GET запроса
//    @GET("api/items")
//    suspend fun getItems(): Response<List<Item>>
//
//    // Пример POST запроса с телом
//    @POST("api/items")
//    suspend fun createItem(@Body item: Item): Response<Item>
//
//    // Пример запроса с параметрами
//    @GET("api/items/{id}")
//    suspend fun getItemById(@Path("id") id: String): Response<Item>
//
//    // Пример запроса с query параметрами
//    @GET("api/items")
//    suspend fun searchItems(@Query("query") query: String): Response<List<Item>>
}