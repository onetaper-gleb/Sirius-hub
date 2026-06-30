import 'package:client/core/dependencies.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_event.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:client/domain/model/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _defaultAvatarEmoji = '😀';

  RegistrationProfileData? _profile;
  String? _error;
  bool _isLoading = true;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _profile = authState.profileModel.registrationProfileData;
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }

    try {
      final profile = await context.dependencies.authRepository
          .getProfileData();
      if (!mounted) return;
      _profile = profile;
      setState(() {
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить профиль';
      });
    }
  }

  void _signOut() {
    context.read<AuthBloc>().add(AuthSignOutRequested());
  }

  Future<void> _openEditScreen() async {
    final current = _profile;
    if (current == null) return;
    final updated = await Navigator.of(context).push<RegistrationProfileData>(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(initialProfile: current),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _profile = updated;
      });
    }
    context.read<AuthBloc>().add(AuthGetProfileDataRequested());
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('Профиль пока недоступен'));
    }

    final avatar = (profile.avatarEmoji ?? '').trim().isEmpty
        ? _defaultAvatarEmoji
        : profile.avatarEmoji!.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                border: Border.all(color: theme.colorScheme.primary, width: 2),
              ),
              child: Text(avatar, style: const TextStyle(fontSize: 42)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              (profile.displayName ?? '').isEmpty
                  ? 'Пользователь'
                  : profile.displayName!,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.groups_outlined,
                    title: 'Группа',
                    value: (profile.groupCode ?? '').isEmpty
                        ? 'Не указана'
                        : profile.groupCode!,
                  ),
                  _infoTile(
                    icon: Icons.send_outlined,
                    title: 'Telegram',
                    value: (profile.telegramHandle ?? '').isEmpty
                        ? 'Не указан'
                        : profile.telegramHandle!,
                  ),
                  _infoTile(
                    icon: Icons.notes_outlined,
                    title: 'О себе',
                    value: (profile.bio ?? '').isEmpty
                        ? 'Не заполнено'
                        : profile.bio!,
                  ),
                ],
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
              onPressed: _openEditScreen,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Редактировать профиль'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Выйти из аккаунта'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
