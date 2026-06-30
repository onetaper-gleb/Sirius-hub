import 'dart:async';

import 'package:client/core/dependencies.dart';
import 'package:client/data/local/emoji.dart';
import 'package:client/data/local/registration_draft_storage.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_event.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:client/domain/model/model.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RegistrationProfileScreen extends StatefulWidget {
  const RegistrationProfileScreen({super.key});

  @override
  State<RegistrationProfileScreen> createState() =>
      _RegistrationProfileScreenState();
}

class _RegistrationProfileScreenState extends State<RegistrationProfileScreen> {
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
  Timer? _persistDebounce;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _displayNameController.addListener(_schedulePersistDraft);
    _groupCodeController.addListener(_schedulePersistDraft);
    _telegramController.addListener(_schedulePersistDraft);
    _bioController.addListener(_schedulePersistDraft);
  }

  Future<void> _loadDraft() async {
    final draft = await RegistrationDraftStorage.loadDraft();
    if (!mounted || draft == null) return;
    setState(() {
      _selectedAvatarEmoji = draft.avatarEmoji ?? _defaultAvatarEmoji;
      _displayNameController.text = draft.displayName ?? '';
      _groupCodeController.text = draft.groupCode ?? '';
      _telegramController.text = draft.telegramHandle ?? '';
      _bioController.text = draft.bio ?? '';
    });
  }

  void _schedulePersistDraft() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), _persistDraft);
  }

  Future<void> _persistDraft() async {
    final data = RegistrationProfileData(
      avatarEmoji: _selectedAvatarEmoji,
      displayName: _displayNameController.text,
      groupCode: _groupCodeController.text.trim().isEmpty
          ? null
          : _groupCodeController.text.trim(),
      telegramHandle: _telegramController.text.trim().isEmpty
          ? null
          : _telegramController.text.trim(),
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
    );
    await RegistrationDraftStorage.saveDraft(data);
  }

  Future<void> _exitRegistration() async {
    await context.dependencies.authRepository.abandonIncompleteRegistration();
    await RegistrationDraftStorage.clearAll();
    if (!mounted) return;
    context.read<AuthBloc>().add(AuthSignOutRequested());
  }

  Future<void> _submit() async {
    final avatar = _selectedAvatarEmoji.trim();
    if (avatar.isEmpty || avatar.contains(' ')) {
      setState(() => _error = 'Выбери один смайлик для аватарки');
      return;
    }
    if (avatar.length > _maxAvatarEmoji) {
      setState(() => _error = 'Смайлик слишком длинный');
      return;
    }

    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _error = 'Укажи, как тебя показывать в профиле');
      return;
    }
    if (displayName.length > _maxDisplayName) {
      setState(
        () => _error = 'Имя для профиля — не длиннее $_maxDisplayName символов',
      );
      return;
    }

    final groupCode = _groupCodeController.text.trim();
    if (groupCode.length > _maxGroupCode) {
      setState(
        () => _error = 'Номер группы — не длиннее $_maxGroupCode символов',
      );
      return;
    }

    final telegram = _telegramController.text.trim();
    if (telegram.length > _maxTelegram) {
      setState(() => _error = 'Telegram — не длиннее $_maxTelegram символов');
      return;
    }

    final bio = _bioController.text.trim();
    if (bio.length > _maxBio) {
      setState(() => _error = 'О себе — не длиннее $_maxBio символов');
      return;
    }

    await _persistDraft();

    if (!mounted) return;
    setState(() => _error = null);
    context.read<AuthBloc>().add(
      AuthCompleteRegistrationRequested(
        profile: RegistrationProfileData(
          avatarEmoji: avatar,
          displayName: displayName,
          groupCode: groupCode.isEmpty ? null : groupCode,
          telegramHandle: telegram.isEmpty ? null : telegram,
          bio: bio.isEmpty ? null : bio,
        ),
      ),
    );
  }

  String? _getErrorMessage(Exception error) {
    if (error is firebase.FirebaseAuthException) {
      return 'Ошибка регистрации.';
    } else if (error is DioException) {
      return 'Ошибка соединения.';
    } else {
      final s = error.toString();
      if (s.startsWith('Exception: ')) {
        return s.substring('Exception: '.length);
      }
      return 'Ошибка регистрации.';
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
                            _schedulePersistDraft();
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
              onTap: () => _showEmojiPicker(theme),
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
  void dispose() {
    _persistDebounce?.cancel();
    _displayNameController.dispose();
    _groupCodeController.dispose();
    _telegramController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = firebase.FirebaseAuth.instance.currentUser?.email ?? '';

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Профиль'),
          actions: [
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                return TextButton(
                  onPressed: state is AuthLoading
                      ? null
                      : () async {
                          await _exitRegistration();
                        },
                  child: const Text('Выйти'),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BlocConsumer<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthError) {
                setState(() {
                  _error = _getErrorMessage(state.error);
                });
              }
            },
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Шаг 2 из 2',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Как тебя видят в CampHub',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildAvatarBlock(theme),
                const SizedBox(height: 20),
                TextField(
                  controller: _displayNameController,
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
                  maxLength: _maxBio,
                  minLines: 1,
                  maxLines: 3,
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
                    onPressed: state is AuthLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: state is AuthLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Завершить регистрацию',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
