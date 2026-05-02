import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_localization.dart';
import '../../core/platform/cover_pick_save.dart';
import '../../core/platform/platform.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// Фрагмент редактирования профиля: аватар, почта/пароль/ник; режим редактирования по кнопке.
class ProfileEditFragment extends StatefulWidget {
  const ProfileEditFragment({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;

  @override
  State<ProfileEditFragment> createState() => _ProfileEditFragmentState();
}

class _ProfileEditFragmentState extends State<ProfileEditFragment> {
  late TextEditingController _nickController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _isEditing = false;
  String? _newAvatarPath;
  String? _passwordError;
  /// Сбрасывает кэш [Image]/[FileImage], если путь тот же после повторного выбора.
  int _avatarDisplayNonce = 0;

  static const double _coverAspectRatio = 1.25;
  static const double _circleAvatarSize = 88.0;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSettings;
    _nickController = TextEditingController(text: s.nickname);
    _emailController = TextEditingController(text: s.email.isNotEmpty ? s.email : 'user@example.com');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _newAvatarPath = s.avatarPath;
  }

  @override
  void dispose() {
    _nickController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _resetFormToInitial() {
    final s = widget.initialSettings;
    _nickController.text = s.nickname;
    _emailController.text = s.email.isNotEmpty ? s.email : 'user@example.com';
    _newAvatarPath = s.avatarPath;
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _passwordError = null;
  }

  void _exitEditing() {
    setState(() {
      _isEditing = false;
      _resetFormToInitial();
    });
  }

  void _enterEditing() {
    setState(() {
      _isEditing = true;
      _passwordError = null;
    });
  }

  Future<void> _save() async {
    _passwordError = null;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final currentPassword = _currentPasswordController.text;
    final storedPassword = widget.initialSettings.password;

    if (newPassword.isNotEmpty || confirmPassword.isNotEmpty || currentPassword.isNotEmpty) {
      if (currentPassword != storedPassword) {
        if (!mounted) return;
        setState(() => _passwordError = context.t('profile.edit.badCurrentPassword'));
        return;
      }
      if (newPassword != confirmPassword) {
        if (!mounted) return;
        setState(() => _passwordError = context.t('profile.edit.passwordMismatch'));
        return;
      }
    }

    final current = await widget.settingsRepository.getSettings();
    final passwordToSave = newPassword.isNotEmpty ? newPassword : storedPassword;
    await widget.settingsRepository.saveSettings(
      current.copyWith(
        nickname: _nickController.text,
        email: _emailController.text,
        password: passwordToSave,
        avatarPath: _newAvatarPath,
      ),
    );
    if (mounted) {
      setState(() {
        _isEditing = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _passwordError = null;
      });
    }
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

  void _showAvatarPicker() {
    final palette = AppPaletteExtension.of(context).palette;
    final paths = [
      'assets/images/identity.png',
      'assets/images/heal_her.png',
      'assets/images/stardust.png',
      'assets/images/geoxor.png',
      'assets/images/xploson.png',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: palette.textMuted.withValues(alpha: 0.25))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        context.t('profile.edit.presets'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textMuted),
                      ),
                    ),
                    Expanded(child: Divider(color: palette.textMuted.withValues(alpha: 0.25))),
                  ],
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: paths.map((path) {
                  final isSelected = _newAvatarPath == path;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _newAvatarPath = path);
                      Navigator.pop(sheetCtx);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            path,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 72,
                              height: 72,
                              color: palette.accent.withValues(alpha: 0.25),
                              child: Icon(Icons.person_rounded, color: palette.accent, size: 32),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                border: Border.all(color: palette.accent, width: 3),
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.black.withValues(alpha: 0.25),
                              ),
                              child: Icon(Icons.check_rounded, color: Colors.white, size: 28),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _effectiveAvatarPath =>
      _newAvatarPath ?? widget.initialSettings.avatarPath ?? kDefaultUserAvatarAsset;

  bool get _avatarChangedFromInitial =>
      (_newAvatarPath ?? '').trim() != (widget.initialSettings.avatarPath ?? '').trim();

  Widget _buildAvatarBlock(BuildContext context, AppColorPalette palette) {
    final showNewBadge = _isEditing && _avatarChangedFromInitial;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accent.withValues(alpha: 0.08),
            palette.primaryLight.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.textMuted.withValues(alpha: 0.15)),
      ),
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
                            child: _effectiveAvatarPath.startsWith('assets/')
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: palette.primaryLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.textMuted.withValues(alpha: 0.12)),
      ),
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
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: palette.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('profile.edit.hintLocal'),
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
          _buildLabeledField(
            palette,
            context.t('profile.edit.fieldNickname'),
            context.t('profile.edit.fieldNicknameHint'),
            _nickController,
            placeholder: context.t('profile.edit.fieldNickname'),
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
          const SizedBox(height: 20),
          _buildSectionHeader(palette, context.t('profile.edit.cardSecurity'), Icons.lock_outline_rounded),
          const SizedBox(height: 10),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
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
          _buildReadOnlyRow(palette, Icons.lock_outline_rounded, context.t('auth.password'), '••••••••'),
        ],
      ],
    );
  }
}
