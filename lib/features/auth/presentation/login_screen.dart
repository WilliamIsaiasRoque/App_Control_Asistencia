import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _continueToNextStep() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'La conexión de acceso con Supabase se integra en el siguiente paso.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 11),
                        const Text(
                          'Bienvenido',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            letterSpacing: -1.4,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Ingresa con el correo y la contraseña de tu cuenta.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 29),
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
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                decoration: const InputDecoration(
                                  hintText: 'nombre@dkpartners.com',
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty || !email.contains('@')) {
                                    return 'Escribe un correo válido.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 19),
                              const _FieldLabel('Contraseña'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _continueToNextStep(),
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
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Escribe tu contraseña.'
                                    : null,
                              ),
                              const SizedBox(height: 9),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setState(
                                  () => _rememberSession = !_rememberSession,
                                ),
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
                                          color: Color(0xFF49534E),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              SizedBox(
                                height: 50,
                                child: FilledButton.icon(
                                  onPressed: _continueToNextStep,
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 19,
                                  ),
                                  label: const Text('Ingresar'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.navy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 17),
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
