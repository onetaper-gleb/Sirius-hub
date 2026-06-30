import 'package:client/core/dependencies.dart';
import 'package:client/data/local/emoji.dart';
import 'package:client/domain/model/model.dart';
import 'package:flutter/material.dart';

class ProfileEditScreen extends StatefulWidget {
  final RegistrationProfileData initialProfile;

  const ProfileEditScreen({super.key, required this.initialProfile});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const int _maxDisplayName = 30;
  static const int _maxGroupCode = 20;
  static const int _maxBio = 200;
  static const int _maxTelegram = 33;
  static const int _maxAvatarEmoji = 16;
  static const String _defaultAvatarEmoji = '😀';

  final _displayNameController = TextEditingController();
  final _groupCodeController = TextEditingController();
  final _telegramController = TextEditingController();
  final _bioController = TextEditingController();

  String _selectedAvatarEmoji = _defaultAvatarEmoji;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fillForm(widget.initialProfile);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _groupCodeController.dispose();
    _telegramController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _fillForm(RegistrationProfileData data) {
    _selectedAvatarEmoji =
        (data.avatarEmoji == null || data.avatarEmoji!.trim().isEmpty)
        ? _defaultAvatarEmoji
        : data.avatarEmoji!.trim();
    _displayNameController.text = data.displayName ?? '';
    _groupCodeController.text = data.groupCode ?? '';
    _telegramController.text = data.telegramHandle ?? '';
    _bioController.text = data.bio ?? '';
  }

  RegistrationProfileData? _buildValidatedData() {
    final avatar = _selectedAvatarEmoji.trim();
    if (avatar.isEmpty || avatar.contains(' ')) {
      setState(() => _error = 'Выбери один смайлик для аватарки');
      return null;
    }
    if (avatar.length > _maxAvatarEmoji) {
      setState(() => _error = 'Смайлик слишком длинный');
      return null;
    }

    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _error = 'Укажи, как тебя показывать в профиле');
      return null;
    }
    if (displayName.length > _maxDisplayName) {
      setState(
        () => _error = 'Имя для профиля — не длиннее $_maxDisplayName символов',
      );
      return null;
    }

    final groupCode = _groupCodeController.text.trim();
    if (groupCode.length > _maxGroupCode) {
      setState(
        () => _error = 'Номер группы — не длиннее $_maxGroupCode символов',
      );
      return null;
    }

    final telegram = _telegramController.text.trim();
    if (telegram.length > _maxTelegram) {
      setState(() => _error = 'Telegram — не длиннее $_maxTelegram символов');
      return null;
    }

    final bio = _bioController.text.trim();
    if (bio.length > _maxBio) {
      setState(() => _error = 'О себе — не длиннее $_maxBio символов');
      return null;
    }

    setState(() => _error = null);
    return RegistrationProfileData(
      avatarEmoji: avatar,
      displayName: displayName,
      groupCode: groupCode.isEmpty ? null : groupCode,
      telegramHandle: telegram.isEmpty ? null : telegram,
      bio: bio.isEmpty ? null : bio,
    );
  }

  Future<void> _saveProfile() async {
    final data = _buildValidatedData();
    if (data == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final updated = await context.dependencies.authRepository
          .updateProfileData(data);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isSaving = false;
        _error = message.isEmpty ? 'Не удалось сохранить профиль' : message;
      });
    }
  }

  void _showEmojiPicker(ThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Выбери смайлик',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 320,
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: Emoji.avatarEmojiOptions.length,
                    itemBuilder: (context, index) {
                      final emoji = Emoji.avatarEmojiOptions[index];
                      final isSelected = emoji == _selectedAvatarEmoji;
                      return Material(
                        color: isSelected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            setState(() {
                              _selectedAvatarEmoji = emoji;
                              _error = null;
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarBlock(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Аватар',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Нажми на смайлик, чтобы выбрать другой',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isSaving ? null : () => _showEmojiPicker(theme),
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                ),
                child: Text(
                  _selectedAvatarEmoji,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать профиль')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAvatarBlock(Theme.of(context)),
            const SizedBox(height: 20),
            TextField(
              controller: _displayNameController,
              enabled: !_isSaving,
              maxLength: _maxDisplayName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя в профиле',
                helperText: 'Как тебя видят другие',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _groupCodeController,
              enabled: !_isSaving,
              maxLength: _maxGroupCode,
              decoration: const InputDecoration(
                labelText: 'Номер группы (необязательно)',
                prefixIcon: Icon(Icons.groups_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _telegramController,
              enabled: !_isSaving,
              maxLength: _maxTelegram,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Telegram (необязательно)',
                helperText: 'Без @ или с @',
                prefixIcon: Icon(Icons.send_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              enabled: !_isSaving,
              maxLength: _maxBio,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'О себе (необязательно)',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Сохранить изменения'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
