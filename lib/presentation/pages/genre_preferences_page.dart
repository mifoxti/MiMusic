import 'package:flutter/material.dart';

import '../../core/auth/auth_session_store.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/user_genre_preferences_api.dart';
import '../../core/studio/studio_constants.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/studio_genre_picker.dart';

/// Настройка явных предпочтений по жанрам ([PUT /me/genre-preferences]).
class GenrePreferencesPage extends StatefulWidget {
  const GenrePreferencesPage({super.key});

  @override
  State<GenrePreferencesPage> createState() => _GenrePreferencesPageState();
}

class _GenrePreferencesPageState extends State<GenrePreferencesPage> {
  List<String> _selected = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final acc = await AuthSessionStore.readAccount();
      if (acc == null || acc.sessionToken.isEmpty || acc.userId == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'login';
          });
        }
        return;
      }
      final prefs = await UserGenrePreferencesApi().fetchPreferences();
      if (!mounted) return;
      setState(() {
        _selected = prefs.map((e) => e.slug).where((s) => studioGenreIds.contains(s)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'net';
        });
      }
    }
  }

  Future<void> _save() async {
    final prefs = _selected
        .map((slug) => GenrePreferenceDto(slug: slug, weight: 1.0))
        .toList();
    try {
      await UserGenrePreferencesApi().savePreferences(prefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('genrePrefs.saved'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('genrePrefs.loadError'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.gradientStart,
            palette.gradientMiddle,
            palette.gradientEnd,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: palette.textPrimary),
          title: Text(
            context.t('genrePrefs.title'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: palette.textPrimary),
          ),
          actions: [
            if (!_loading && _error == null)
              TextButton(
                onPressed: _save,
                child: Text(context.t('genrePrefs.save')),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : _error == 'login'
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.t('studio.serverNeedLogin'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: TextButton(onPressed: _load, child: Text(context.t('genrePrefs.loadError'))),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          Text(
                            context.t('genrePrefs.subtitle'),
                            style: TextStyle(fontSize: 14, color: palette.textSecondary, height: 1.35),
                          ),
                          const SizedBox(height: 20),
                          StudioGenrePicker(
                            palette: palette,
                            selected: _selected,
                            onSelectionChanged: (v) => setState(() => _selected = v),
                          ),
                        ],
                      ),
      ),
    );
  }
}
