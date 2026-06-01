import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/server_avatar_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/profile_api.dart';
import '../../core/network/server_connectivity.dart';
import '../../core/network/users_api.dart';
import '../../core/profile/me_avatar_cache_refresh.dart';
import '../../core/profile/me_profile_cache.dart';
import '../../core/platform/avatar_upload_encode.dart';
import '../../core/platform/cover_pick_save.dart';
import '../../core/platform/platform.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glass_snack_bar.dart';
import '../widgets/server_me_avatar.dart';
import '../widgets/user_avatar.dart';

/// Фрагмент редактирования профиля: аватар, почта/пароль/ник; режим редактирования по кнопке.
class ProfileEditFragment extends StatefulWidget {
  const ProfileEditFragment({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
    this.onProfileSaved,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  /// После успешного сохранения — обновить [initialSettings] у родителя (например, с диска).
  final Future<void> Function()? onProfileSaved;

  @override
  State<ProfileEditFragment> createState() => _ProfileEditFragmentState();
}

class _ProfileEditFragmentState extends State<ProfileEditFragment> {
  late TextEditingController _nickController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _isEditing = false;
  /// Есть сессия с userId — правки уходят на сервер при сохранении.
  bool _serverSession = false;
  String? _newAvatarPath;
  String? _passwordError;
  /// Сбрасывает кэш [Image]/[FileImage], если путь тот же после повторного выбора.
  int _avatarDisplayNonce = 0;
  Timer? _nickAvailDebounce;
  bool _nicknameFieldTaken = false;
  bool _saving = false;

  static const double _coverAspectRatio = 1.25;
  static const double _circleAvatarSize = 88.0;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSettings;
    _nickController = TextEditingController(text: s.nickname);
    _emailController = TextEditingController(text: s.email.isNotEmpty ? s.email : 'user@example.com');
    _bioController = TextEditingController(text: s.bio);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _newAvatarPath = s.avatarPath;
    _nickController.addListener(_onNicknameAvailabilityDebounced);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_syncProfileFromServer()));
  }

  Future<void> _syncProfileFromServer() async {
    final acc = await AuthSessionStore.readAccount();
    final loggedIn =
        acc != null && acc.sessionToken.trim().isNotEmpty && acc.userId != null;
    if (mounted) setState(() => _serverSession = loggedIn);
    if (acc == null || acc.userId == null || !loggedIn) return;
    final uid = acc.userId!;
    try {
      final me = await ProfileApi().fetchMe();
      if (!mounted) return;
      await MeProfileCache.save(uid, me);
      // Пока пользователь в режиме правок, не затирать поля и выбранный файл аватара
      // (иначе поздний ответ /me сбрасывает локальный путь после выбора из галереи).
      if (_isEditing) return;
      setState(() {
        _nickController.text = me.nickname;
        if (me.email != null && me.email!.trim().isNotEmpty) {
          _emailController.text = me.email!.trim();
        }
        _bioController.text = me.bio ?? '';
        if (me.avatarStorageKey != null && me.avatarStorageKey!.trim().isNotEmpty) {
          _newAvatarPath = kServerMeAvatarMarker;
        }
      });
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant ProfileEditFragment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isEditing) return;
    final o = oldWidget.initialSettings;
    final n = widget.initialSettings;
    if (o.avatarPath == n.avatarPath &&
        o.nickname == n.nickname &&
        o.email == n.email &&
        o.bio == n.bio) {
      return;
    }
    setState(() {
      _nickController.text = n.nickname;
      _emailController.text = n.email.isNotEmpty ? n.email : 'user@example.com';
      _bioController.text = n.bio;
      _newAvatarPath = n.avatarPath;
    });
  }

  void _onNicknameAvailabilityDebounced() {
    _nickAvailDebounce?.cancel();
    if (!_isEditing || !_serverSession) {
      if (_nicknameFieldTaken) setState(() => _nicknameFieldTaken = false);
      return;
    }
    final t = _nickController.text.trim();
    final initial = widget.initialSettings.nickname.trim();
    if (t.length < 2 || t.toLowerCase() == initial.toLowerCase()) {
      if (_nicknameFieldTaken) setState(() => _nicknameFieldTaken = false);
      return;
    }
    _nickAvailDebounce = Timer(const Duration(milliseconds: 500), () async {
      final acc = await AuthSessionStore.readAccount();
      final uid = acc?.userId;
      if (!mounted || uid == null) return;
      try {
        final ok = await UsersApi().isNicknameAvailable(t, exceptUserId: uid);
        if (!mounted) return;
        final wasTaken = _nicknameFieldTaken;
        final nowTaken = !ok;
        setState(() => _nicknameFieldTaken = nowTaken);
        if (!wasTaken && nowTaken && mounted) {
          showGlassSnackBar(context, context.t('profile.edit.nicknameTaken'));
        }
      } catch (_) {
        if (!mounted) return;
        if (_nicknameFieldTaken) setState(() => _nicknameFieldTaken = false);
      }
    });
  }

  @override
  void dispose() {
    _nickController.removeListener(_onNicknameAvailabilityDebounced);
    _nickAvailDebounce?.cancel();
    _nickController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _resetFormToInitial() {
    final s = widget.initialSettings;
    _nickController.text = s.nickname;
    _emailController.text = s.email.isNotEmpty ? s.email : 'user@example.com';
    _bioController.text = s.bio;
    _newAvatarPath = s.avatarPath;
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _passwordError = null;
  }

  void _exitEditing() {
    setState(() {
      _isEditing = false;
      _nicknameFieldTaken = false;
      _resetFormToInitial();
    });
  }

  void _enterEditing() {
    setState(() {
      _isEditing = true;
      _passwordError = null;
      _nicknameFieldTaken = false;
    });
  }

  String _avatarUploadDetail(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is String && data.trim().isNotEmpty) {
        final t = data.trim();
        return t.length > 180 ? '${t.substring(0, 177)}…' : t;
      }
      final code = e.response?.statusCode;
      if (code != null) return 'HTTP $code';
    }
    return e.toString();
  }

  void _showAvatarUploadErrorSnack(Object e) {
    if (!mounted) return;
    final String title;
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401) {
        title = context.t('profile.edit.avatarUploadUnauthorized');
      } else if (code == 413) {
        title = context.t('profile.edit.avatarPayloadTooLarge');
      } else {
        title = context.t('profile.edit.avatarUploadFailed');
      }
    } else {
      title = context.t('profile.edit.avatarUploadFailed');
    }
    final detail = e is DioException && e.response?.statusCode == 401
        ? ''
        : _avatarUploadDetail(e).trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(detail.isEmpty ? title : '$title\n$detail')),
    );
  }

  bool _needsAvatarUpload(String? path) {
    if (path == null || path.isEmpty) return false;
    return path != kServerMeAvatarMarker;
  }

  Future<bool> _uploadAvatarToServer(String path) async {
    Future<bool> uploadFile(File file) async {
      File? tempPng;
      try {
        final png = await encodeImageFileToTempPngForAvatarUpload(file);
        tempPng = png;
        await ProfileApi().uploadAvatar(png);
        return true;
      } catch (e) {
        if (mounted) _showAvatarUploadErrorSnack(e);
        return false;
      } finally {
        final t = tempPng;
        if (t != null && await t.exists()) {
          try {
            await t.delete();
          } catch (_) {}
        }
      }
    }

    if (!path.startsWith('assets/')) {
      final f = File(path);
      if (!await f.exists()) return false;
      return uploadFile(f);
    }

    File? rawPng;
    File? resized;
    try {
      rawPng = await _materializeAssetToTempPng(path);
      resized = await encodeImageFileToTempPngForAvatarUpload(rawPng);
      await ProfileApi().uploadAvatar(resized);
      return true;
    } catch (e) {
      if (mounted) _showAvatarUploadErrorSnack(e);
      return false;
    } finally {
      for (final f in <File?>[rawPng, resized]) {
        if (f != null && await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    if (mounted) setState(() {});
    try {
    _passwordError = null;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final currentPassword = _currentPasswordController.text.trim();
    final storedPassword = widget.initialSettings.password;

    final acc = await AuthSessionStore.readAccount();
    final server = acc != null &&
        acc.sessionToken.trim().isNotEmpty &&
        acc.userId != null;

    final touchedPassword =
        newPassword.isNotEmpty || confirmPassword.isNotEmpty || currentPassword.isNotEmpty;
    if (touchedPassword) {
      if (newPassword != confirmPassword) {
        if (!mounted) return;
        setState(() => _passwordError = context.t('profile.edit.passwordMismatch'));
        return;
      }
      if (newPassword.isNotEmpty && newPassword.length < 6) {
        if (!mounted) return;
        setState(() => _passwordError = context.t('profile.edit.fieldNewPasswordHint'));
        return;
      }
      if (server) {
        if (newPassword.isNotEmpty && currentPassword.isEmpty) {
          if (!mounted) return;
          setState(() => _passwordError = context.t('profile.edit.fieldCurrentPasswordHint'));
          return;
        }
      } else {
        if (currentPassword != storedPassword) {
          if (!mounted) return;
          setState(() => _passwordError = context.t('profile.edit.badCurrentPassword'));
          return;
        }
      }
    }

    final current = await widget.settingsRepository.getSettings();
    final passwordToSave = newPassword.isNotEmpty ? newPassword : storedPassword;
    var avatarToSave = _newAvatarPath;
    if (server) {
      if (!mounted) return;
      if (!await ServerConnectivity.instance.ensureOnline(context)) return;
      final nickTrim = _nickController.text.trim();
      final initialNick = widget.initialSettings.nickname.trim();
      if (nickTrim.isNotEmpty &&
          nickTrim.toLowerCase() != initialNick.toLowerCase() &&
          acc.userId != null) {
        try {
          final free = await UsersApi().isNicknameAvailable(
            nickTrim,
            exceptUserId: acc.userId,
          );
          if (!free) {
            if (!mounted) return;
            setState(() => _nicknameFieldTaken = true);
            showGlassSnackBar(context, context.t('profile.edit.nicknameTaken'));
            return;
          }
        } catch (_) {}
      }
      try {
        await ProfileApi().patchMe(
          nickname: nickTrim,
          email: _emailController.text.trim(),
          bio: _bioController.text.trim(),
        );
      } on DioException catch (e) {
        if (!mounted) return;
        if (e.response?.statusCode == 409) {
          final body = e.response?.data?.toString() ?? '';
          final emailConflict = body.contains('Email');
          if (!emailConflict) {
            setState(() => _nicknameFieldTaken = true);
          }
          showGlassSnackBar(
            context,
            emailConflict
                ? context.t('profile.edit.emailTaken')
                : context.t('profile.edit.nicknameTaken'),
          );
          return;
        }
        if (e.response?.statusCode == 401) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('profile.edit.avatarUploadUnauthorized'))),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t('profile.edit.save')}: ${_avatarUploadDetail(e)}')),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t('profile.edit.save')}: $e')),
        );
        return;
      }
      // Аватар до смены пароля: на сервере одна сессия на пользователя; порядок снижает шанс 401 на upload.
      final ap = _newAvatarPath;
      if (_needsAvatarUpload(ap)) {
        final uploaded = await _uploadAvatarToServer(ap!);
        if (!uploaded) {
          return;
        }
        avatarToSave = kServerMeAvatarMarker;
        final nextRevision = _avatarDisplayNonce + 1;
        await refreshCachedMeAvatar(cacheRevision: nextRevision);
        if (mounted) {
          setState(() => _avatarDisplayNonce = nextRevision);
        }
      }
      if (newPassword.isNotEmpty) {
        try {
          await ProfileApi().changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
        } on DioException catch (e) {
          if (!mounted) return;
          final code = e.response?.statusCode;
          final body = e.response?.data;
          final detail = body is String ? body : '$body';
          if (code == 401 || (detail.contains('Wrong current password'))) {
            setState(() => _passwordError = context.t('profile.edit.badCurrentPassword'));
            return;
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.t('profile.edit.save')}: $detail')),
          );
          return;
        }
      }
    }
    await widget.settingsRepository.saveSettings(
      current.copyWith(
        nickname: _nickController.text,
        email: _emailController.text,
        bio: _bioController.text,
        password: server ? '' : passwordToSave,
        avatarPath: avatarToSave,
      ),
    );
    if (server && acc.userId != null) {
      try {
        final me = await ProfileApi().fetchMe();
        await MeProfileCache.save(acc.userId!, me);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isEditing = false;
        _nicknameFieldTaken = false;
        _newAvatarPath = avatarToSave;
        _avatarDisplayNonce++;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _passwordError = null;
      });
    }
    await widget.onProfileSaved?.call();
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  static Future<File> _materializeAssetToTempPng(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/mimusic_avatar_upload_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(data.buffer.asUint8List());
    return f;
  }

  Future<void> _pickCustomAvatar(BuildContext sheetContext) async {
    if (!sheetContext.mounted) return;
    // Сначала закрыть лист: иначе FilePicker часто не открывается или сразу отменяется (Android).
    Navigator.of(sheetContext).pop();

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('profile.edit.customPhotoUnavailable'))),
        );
      });
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final path = await pickAndSaveCoverImage('profile_avatar');
    if (!mounted) return;
    if (path != null) {
      setState(() {
        _newAvatarPath = path;
        _avatarDisplayNonce++;
      });
    }
  }

  static const String _templateAvatarAsset = 'assets/images/identity.png';

  void _showAvatarPicker() {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassTint = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.34);
    final borderGlass = Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final bottomPad =
            MediaQuery.paddingOf(sheetCtx).bottom + AppConstants.shellBottomInset + 12;
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  border: Border.all(color: borderGlass),
                  color: glassTint,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: palette.textMuted.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Text(
                        context.t('profile.edit.sheetTitle'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.add_photo_alternate_outlined, color: palette.accent, size: 22),
                        ),
                        title: Text(
                          context.t('profile.edit.fromGallery'),
                          style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
                        ),
                        subtitle: Text(
                          context.t('profile.edit.fromGallerySub'),
                          style: TextStyle(fontSize: 12, color: palette.textSecondary),
                        ),
                        onTap: () => _pickCustomAvatar(sheetCtx),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            _templateAvatarAsset,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 44,
                              height: 44,
                              color: palette.accent.withValues(alpha: 0.2),
                              child: Icon(Icons.person_rounded, color: palette.accent),
                            ),
                          ),
                        ),
                        title: Text(
                          context.t('profile.edit.defaultAvatar'),
                          style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
                        ),
                        subtitle: Text(
                          context.t('profile.edit.defaultAvatarSub'),
                          style: TextStyle(fontSize: 12, color: palette.textSecondary),
                        ),
                        onTap: () {
                          setState(() {
                            _newAvatarPath = _templateAvatarAsset;
                            _avatarDisplayNonce++;
                          });
                          Navigator.pop(sheetCtx);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String get _effectiveAvatarPath =>
      _newAvatarPath ?? widget.initialSettings.avatarPath ?? kDefaultUserAvatarAsset;

  bool get _avatarChangedFromInitial =>
      (_newAvatarPath ?? '').trim() != (widget.initialSettings.avatarPath ?? '').trim();

  Widget _buildAvatarBlock(BuildContext context, AppColorPalette palette) {
    final showNewBadge = _isEditing && _avatarChangedFromInitial;

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.face_retouching_natural_rounded, size: 18, color: palette.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('profile.edit.avatarTitle'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.t('profile.edit.avatarSubtitle'),
            style: TextStyle(fontSize: 12, height: 1.35, color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          palette.accent,
                          palette.accent.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                    child: UserAvatar(
                      key: ValueKey('edit-avatar-$_avatarDisplayNonce-$_effectiveAvatarPath'),
                      avatarPath: _effectiveAvatarPath,
                      size: _circleAvatarSize,
                      palette: palette,
                      serverAvatarCacheRevision: _avatarDisplayNonce,
                    ),
                  ),
                  if (showNewBadge)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          context.t('profile.edit.newAvatar'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showNewBadge ? context.t('profile.edit.newAvatar') : context.t('profile.edit.currentAvatar'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textMuted),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = (width * _coverAspectRatio).clamp(96.0, 140.0);
                        return ClipRRect(
                          key: ValueKey('edit-cover-$_avatarDisplayNonce-$_effectiveAvatarPath'),
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: _effectiveAvatarPath == kServerMeAvatarMarker
                                ? ServerMeAvatar(
                                    clipCircle: false,
                                    size: width,
                                    boxWidth: width,
                                    boxHeight: height,
                                    palette: palette,
                                    cacheRevision: _avatarDisplayNonce,
                                  )
                                : _effectiveAvatarPath.startsWith('assets/')
                                    ? Image.asset(
                                        _effectiveAvatarPath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => _avatarPlaceholder(width, height, palette),
                                      )
                                    : buildCoverImageFromFile(
                                        _effectiveAvatarPath,
                                        width,
                                        height,
                                        BorderRadius.zero,
                                        _avatarPlaceholder(width, height, palette),
                                        BoxFit.cover,
                                      ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _showAvatarPicker,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text(context.t('profile.edit.changeAvatar')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(double w, double h, AppColorPalette palette) {
    return Container(
      width: w,
      height: h,
      color: palette.accent.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, color: palette.accent, size: 40),
    );
  }

  Widget _buildLabeledField(
    AppColorPalette palette,
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool obscure = false,
    String? placeholder,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 15, color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
            errorText: errorText,
            errorStyle: TextStyle(fontSize: 12, height: 1.25, color: Colors.red.shade700),
            filled: true,
            fillColor: palette.cardBackground.withValues(alpha: 0.65),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.textMuted.withValues(alpha: 0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.textMuted.withValues(alpha: 0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(AppColorPalette palette, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: palette.accent),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(AppColorPalette palette, IconData icon, String label, String value) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      margin: const EdgeInsets.only(bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: palette.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, height: 1.25, color: palette.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.t('profile.edit.section').toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                if (_isEditing) {
                  _exitEditing();
                } else {
                  _enterEditing();
                }
              },
              icon: Icon(
                _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                size: 22,
                color: palette.accent,
              ),
              tooltip: _isEditing ? context.t('profile.edit.tooltipClose') : context.t('profile.edit.tooltipEdit'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isEditing)
          GlassPanel(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: palette.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _serverSession
                        ? context.t('profile.edit.hintServer')
                        : context.t('profile.edit.hintLocal'),
                    style: TextStyle(fontSize: 12, height: 1.35, color: palette.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        _buildAvatarBlock(context, palette),
        const SizedBox(height: 20),
        if (_isEditing) ...[
          _buildSectionHeader(palette, context.t('profile.edit.cardPersonal'), Icons.badge_outlined),
          const SizedBox(height: 10),
          GlassPanel(
            child: Column(
              children: [
                _buildLabeledField(
                  palette,
                  context.t('profile.edit.fieldNickname'),
                  context.t('profile.edit.fieldNicknameHint'),
                  _nickController,
                  placeholder: context.t('profile.edit.fieldNickname'),
                  errorText: _nicknameFieldTaken ? context.t('profile.edit.nicknameTaken') : null,
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  palette,
                  context.t('profile.edit.fieldEmail'),
                  context.t('profile.edit.fieldEmailHint'),
                  _emailController,
                  keyboardType: TextInputType.emailAddress,
                  placeholder: 'email@example.com',
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  palette,
                  context.t('profile.edit.fieldBio'),
                  context.t('profile.edit.fieldBioHint'),
                  _bioController,
                  placeholder: context.t('profile.edit.fieldBio'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(palette, context.t('profile.edit.cardSecurity'), Icons.lock_outline_rounded),
          const SizedBox(height: 10),
          GlassPanel(
            child: Column(
              children: [
                _buildLabeledField(
                  palette,
                  context.t('profile.edit.fieldCurrentPassword'),
                  context.t('profile.edit.fieldCurrentPasswordHint'),
                  _currentPasswordController,
                  obscure: true,
                  placeholder: '••••••••',
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  palette,
                  context.t('profile.edit.fieldNewPassword'),
                  context.t('profile.edit.fieldNewPasswordHint'),
                  _newPasswordController,
                  obscure: true,
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  palette,
                  context.t('profile.edit.fieldConfirmPassword'),
                  context.t('profile.edit.fieldConfirmPasswordHint'),
                  _confirmPasswordController,
                  obscure: true,
                ),
                if (_passwordError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _passwordError!,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(context.t('profile.edit.save')),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ] else ...[
          _buildReadOnlyRow(palette, Icons.person_outline_rounded, context.t('profile.edit.fieldNickname'), _nickController.text),
          const SizedBox(height: 10),
          _buildReadOnlyRow(palette, Icons.alternate_email_rounded, context.t('profile.edit.fieldEmail'), _emailController.text),
          const SizedBox(height: 10),
          _buildReadOnlyRow(palette, Icons.notes_outlined, context.t('profile.edit.fieldBio'), _bioController.text.trim().isEmpty ? '—' : _bioController.text),
          const SizedBox(height: 10),
          _buildReadOnlyRow(palette, Icons.lock_outline_rounded, context.t('auth.password'), '••••••••'),
        ],
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
      ],
    );
  }
}
