import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'album.dart';
import 'studio_repository.dart';

const String _keyAlbums = 'mimusic_studio_albums';
const String _keyTrackOverrides = 'mimusic_studio_track_overrides';
const String _keyCustomTrackPaths = 'mimusic_studio_custom_track_paths';

/// Локальное хранение данных студии через SharedPreferences.
class LocalStudioRepository implements StudioRepository {
  LocalStudioRepository([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<List<Album>> getAlbums() async {
    final prefs = await _instance;
    final jsonStr = prefs.getString(_keyAlbums);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => Album.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveAlbums(List<Album> albums) async {
    final prefs = await _instance;
    final list = albums.map((a) => a.toJson()).toList();
    await prefs.setString(_keyAlbums, jsonEncode(list));
  }

  @override
  Future<Map<String, TrackMetadataOverride>> getTrackMetadataOverrides() async {
    final prefs = await _instance;
    final jsonStr = prefs.getString(_keyTrackOverrides);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, TrackMetadataOverride.fromJson(Map<String, dynamic>.from(v as Map))));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveTrackMetadataOverride(String assetPath, TrackMetadataOverride? override) async {
    final overrides = await getTrackMetadataOverrides();
    if (override == null) {
      overrides.remove(assetPath);
    } else {
      overrides[assetPath] = override;
    }
    final prefs = await _instance;
    final map = overrides.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_keyTrackOverrides, jsonEncode(map));
  }

  @override
  Future<List<String>> getCustomTrackPaths() async {
    final prefs = await _instance;
    final jsonStr = prefs.getString(_keyCustomTrackPaths);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveCustomTrackPaths(List<String> paths) async {
    final prefs = await _instance;
    await prefs.setString(_keyCustomTrackPaths, jsonEncode(paths));
  }
}
