import 'package:client/domain/bloc/auth/auth_event.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordRepeatController = TextEditingController();

  bool _isLogin = true;
  String? _error;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final passwordRepeat = _passwordRepeatController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Заполни все поля');
      return;
    } else if (!_isLogin && password != passwordRepeat) {
      setState(() => _error = 'Пароли не сопадают');
      return;
    }

    if (_isLogin) {
      context.read<AuthBloc>().add(
        AuthSignInRequested(email: email, password: password),
      );
      return;
    }

    setState(() => _error = null);
    context.read<AuthBloc>().add(
      AuthSignUpBasicRequested(email: email, password: password),
    );
  }

  String? _getErrorMessage(Exception error) {
    if (error is firebase.FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
          return 'Неверные почта или пароль';
        case 'user-disabled':
          return 'Неверные почта или пароль.';
        case 'user-not-found':
          return 'Неверные почта или пароль.';
        case 'invalid-credential':
          return 'Неверные почта или пароль.';
        case 'email-already-in-use':
          return 'Эта почта уже используется.';
        case 'invalid-email':
          return 'Неправильный формат почты.';
        case 'weak-password':
          return 'Слабый пароль.';
        case 'no-current-user':
          return null;
        default:
          return 'Ошибка ${_isLogin ? "входа" : "регистрации"}.';
      }
    } else if (error is DioException) {
      return 'Ошибка соединения.';
    } else {
      final s = error.toString();
      if (s.startsWith('Exception: ')) {
        return s.substring('Exception: '.length);
      }
      return 'Ошибка ${_isLogin ? "входа" : "регистрации"}.';
    }
  }

  void _switchType() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      if (_isLogin) {
        _passwordRepeatController.clear();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordRepeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BlocConsumer<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthError) {
                AuthError authError = state;
                setState(() {
                  _error = _getErrorMessage(authError.error);
                });
              } else if (_error != null) {
                setState(() => _error = null);
              }
            },
            builder: (context, state) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icon/icon_tansparent.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'Кампус.Хаб',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (!_isLogin) ...[
                  TextField(
                    controller: _passwordRepeatController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Повторите пароль',
                      prefixIcon: Icon(Icons.lock_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Дальше настроим профиль: имя, аватар и контакты.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (_error != null) ...[
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
                  const SizedBox(height: 16),
                ],

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
                        : Text(
                            _isLogin ? 'Войти' : 'Продолжить',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => _switchType(),
                  child: Text(
                    _isLogin
                        ? 'Нет аккаунта? Зарегистрируйся'
                        : 'Уже есть аккаунт? Войди',
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
