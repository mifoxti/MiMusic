import 'package:flutter/material.dart';

import '../../core/l10n/app_localization.dart';
import '../../core/network/genres_api.dart';
import '../../core/studio/studio_constants.dart';
import '../../core/theme/app_colors.dart';

/// Поиск по жанрам + чипы; подгружает [GET /genres] при старте, иначе локальный каталог.
class StudioGenrePicker extends StatefulWidget {
  const StudioGenrePicker({
    super.key,
    required this.palette,
    required this.selected,
    required this.onSelectionChanged,
  });

  final AppColorPalette palette;
  final List<String> selected;
  final ValueChanged<List<String>> onSelectionChanged;

  @override
  State<StudioGenrePicker> createState() => _StudioGenrePickerState();
}

class _StudioGenrePickerState extends State<StudioGenrePicker> {
  final _searchCtrl = TextEditingController();
  List<String> _orderedSlugs = List<String>.from(studioGenreIds);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    try {
      final remote = await GenresApi().fetchGenres();
      if (!mounted) return;
      if (remote.isNotEmpty) {
        remote.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        setState(() {
          _orderedSlugs = remote.map((e) => e.slug).toList();
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _labelForSlug(BuildContext context, String slug) {
    final key = 'studio.genre.$slug';
    final t = context.t(key);
    return t == key ? slug : t;
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _orderedSlugs.where((slug) {
      if (q.isEmpty) return true;
      final label = _labelForSlug(context, slug).toLowerCase();
      return label.contains(q) || slug.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: widget.palette.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: context.t('studio.genreSearchHint'),
            hintStyle: TextStyle(color: widget.palette.textMuted, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: widget.palette.textSecondary, size: 22),
            filled: true,
            fillColor: widget.palette.primaryDark.withValues(alpha: 0.22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: widget.palette.textPrimary.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: widget.palette.textPrimary.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: widget.palette.accent.withValues(alpha: 0.55)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: widget.palette.accent),
              ),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: filtered.map((gid) {
              final selected = widget.selected.contains(gid);
              return FilterChip(
                label: Text(_labelForSlug(context, gid)),
                selected: selected,
                onSelected: (v) {
                  final next = List<String>.from(widget.selected);
                  if (v) {
                    if (!next.contains(gid)) next.add(gid);
                  } else {
                    next.remove(gid);
                  }
                  widget.onSelectionChanged(normalizeStudioGenreList(next));
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
