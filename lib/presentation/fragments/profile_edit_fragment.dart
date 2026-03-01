import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Фрагмент редактирования профиля: аватар по центру, почта/пароль/ник только для чтения
/// до нажатия на карандаш; смена пароля только после подтверждения текущего.
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

  Future<void> _save() async {
    _passwordError = null;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final currentPassword = _currentPasswordController.text;
    final storedPassword = widget.initialSettings.password;

    if (newPassword.isNotEmpty || confirmPassword.isNotEmpty || currentPassword.isNotEmpty) {
      if (currentPassword != storedPassword) {
        setState(() => _passwordError = 'Неверный текущий пароль');
        return;
      }
      if (newPassword != confirmPassword) {
        setState(() => _passwordError = 'Пароли не совпадают');
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
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Выберите аватар',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: palette.textPrimary),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: paths.map((path) {
                  final isSelected = _newAvatarPath == path;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _newAvatarPath = path);
                      Navigator.pop(ctx);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            path,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
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
                                borderRadius: BorderRadius.circular(12),
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

  /// Превью аватара как на странице профиля: полноширинная обложка с пропорцией.
  static const double _coverAspectRatio = 1.25;

  static const double _circleAvatarSize = 80.0;

  Widget _buildAvatarPreview(BuildContext context, AppColorPalette palette) {
    final imagePath = _newAvatarPath ?? widget.initialSettings.avatarPath ?? 'assets/images/identity.png';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _newAvatarPath == null ? 'Текущий аватар' : 'Новый аватар',
          style: TextStyle(fontSize: 12, color: palette.textMuted),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCircleAvatar(imagePath, palette),
            const SizedBox(width: 14),
            Expanded(child: _buildLargePreview(imagePath, palette)),
          ],
        ),
        if (_isEditing) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _showAvatarPicker,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Сменить',
              style: TextStyle(fontSize: 13, color: palette.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCircleAvatar(String imagePath, AppColorPalette palette) {
    return ClipOval(
      child: SizedBox(
        width: _circleAvatarSize,
        height: _circleAvatarSize,
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: _circleAvatarSize,
            height: _circleAvatarSize,
            color: palette.accent.withValues(alpha: 0.25),
            child: Icon(Icons.person_rounded, color: palette.accent, size: 36),
          ),
        ),
      ),
    );
  }

  Widget _buildLargePreview(String imagePath, AppColorPalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width * _coverAspectRatio).clamp(100.0, 180.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: width,
                height: height,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: width,
                    height: height,
                    color: palette.accent.withValues(alpha: 0.25),
                    child: Icon(Icons.person_rounded, color: palette.accent, size: 48),
                  ),
                ),
              ),
            ),
            if (_newAvatarPath != null)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.check_rounded, size: 16, color: Colors.white),
                ),
              ),
          ],
        );
      },
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
              'ПРОФИЛЬ',
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
                setState(() {
                  _isEditing = !_isEditing;
                  _passwordError = null;
                  if (!_isEditing) {
                    _currentPasswordController.clear();
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                  }
                });
              },
              icon: Icon(
                _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                size: 22,
                color: palette.accent,
              ),
              tooltip: _isEditing ? 'Закрыть' : 'Редактировать',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAvatarPreview(context, palette),
        const SizedBox(height: 20),
        if (_isEditing) ...[
          _buildField(palette, 'Никнейм', _nickController),
          const SizedBox(height: 12),
          _buildField(palette, 'Почта', _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _buildField(palette, 'Текущий пароль', _currentPasswordController, obscure: true, hint: 'Для смены пароля'),
          const SizedBox(height: 12),
          _buildField(palette, 'Новый пароль', _newPasswordController, obscure: true),
          const SizedBox(height: 12),
          _buildField(palette, 'Повторите пароль', _confirmPasswordController, obscure: true),
          if (_passwordError != null) ...[
            const SizedBox(height: 8),
            Text(
              _passwordError!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Сохранить'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ] else ...[
          _buildReadOnlyRow(palette, 'Никнейм', _nickController.text),
          const SizedBox(height: 10),
          _buildReadOnlyRow(palette, 'Почта', _emailController.text),
          const SizedBox(height: 10),
          _buildReadOnlyRow(palette, 'Пароль', '••••••••'),
        ],
      ],
    );
  }

  Widget _buildReadOnlyRow(AppColorPalette palette, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.primaryLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.textMuted.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15, color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    AppColorPalette palette,
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool obscure = false,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 16, color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        filled: true,
        fillColor: palette.primaryLight.withValues(alpha: 0.6),
        border: UnderlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.textMuted.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
