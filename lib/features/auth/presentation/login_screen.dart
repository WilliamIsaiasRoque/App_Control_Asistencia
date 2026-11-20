import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/remember_session_storage.dart';
import '../../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _rememberSession = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberPreference();
  }

  Future<void> _loadRememberPreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rememberSession = preferences.getBool('dk_remember_session') ?? true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await RememberSessionStorage.setRememberSession(_rememberSession);
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException {
      if (mounted) {
        setState(() {
          _errorMessage =
              'No se pudo iniciar sesión. Revisa tu correo y contraseña.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'No se pudo conectar. Revisa tu internet e inténtalo otra vez.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 44,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 112,
                            height: 82,
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(5),
                            child: Image.asset(
                              'assets/branding/dkpartners.png',
                              fit: BoxFit.contain,
                              semanticLabel: 'DK Partners',
                            ),
                          ),
                        ),
                        const SizedBox(height: 38),
                        const Text(
                          'PORTAL DEL EQUIPO',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            letterSpacing: 2.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bienvenido',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ingresa con el correo y contraseña de tu cuenta.',
                          style: TextStyle(color: AppColors.muted, height: 1.5),
                        ),
                        const SizedBox(height: 30),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _FieldLabel('Correo electrónico'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  hintText: 'nombre@dkpartners.com',
                                ),
                                validator: (value) {
                                  if (value == null || !value.contains('@')) {
                                    return 'Ingresa un correo válido.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              const _FieldLabel('Contraseña'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _signIn(),
                                decoration: InputDecoration(
                                  hintText: 'Tu contraseña',
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword
                                        ? 'Ocultar contraseña'
                                        : 'Mostrar contraseña',
                                    onPressed: () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 19,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Ingresa tu contraseña.'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              InkWell(
                                onTap: () => setState(
                                  () => _rememberSession = !_rememberSession,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox.adaptive(
                                        value: _rememberSession,
                                        onChanged: (value) => setState(
                                          () =>
                                              _rememberSession = value ?? false,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        activeColor: AppColors.navy,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Mantener sesión iniciada',
                                        style: TextStyle(
                                          color: AppColors.ink,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0EE),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFA3443A),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 50,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _signIn,
                                  child: _isLoading
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Ingresar'),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                '¿Olvidaste tu contraseña? Pídele al administrador que te asigne una temporal.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 17,
                              color: AppColors.muted,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Acceso privado para el equipo DK Partners',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          '¿Necesitas acceso? Pídele una cuenta al administrador.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF98A29D),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF49534E),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}
