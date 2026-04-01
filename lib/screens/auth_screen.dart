import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:email_validator/email_validator.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  GoogleSignIn? _googleSignIn;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _initializeGoogleSignIn() {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      
      _googleSignIn = googleSignIn;
       _googleSignIn?.onCurrentUserChanged.listen(_handleGoogleSignIn);
      _checkExistingSession();
    } catch (e) {
      print('Error initializing Google Sign In: $e');
    }
  }

  Future<void> _checkExistingSession() async {
    try {
      final account = await _googleSignIn?.signInSilently();
      if (account != null && mounted) {
        await _handleGoogleSignIn(account);
      }
    } catch (e) {
      print('Error checking existing session: $e');
    }
  }

  // ==================== GOOGLE SIGN IN ====================
  Future<void> _handleGoogleSignIn(GoogleSignInAccount? account) async {
    if (account == null || !mounted) return;
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAuthentication googleAuth = await account.authentication;
       final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'nickname': user.email!.split('@')[0].toLowerCase(),
          'photoUrl': user.photoURL ?? '',
          'bio': '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } else {
        await userDoc.update({
          'lastSeen': FieldValue.serverTimestamp(),
          'photoUrl': user.photoURL ?? docSnapshot.data()?['photoUrl'],
        });
      }

      if (mounted) {
        Fluttertoast.showToast(msg: "Вход через Google выполнен успешно!", gravity: ToastGravity.BOTTOM);
      }
    } catch (e) {
      print('Google Sign In Error: $e');
      if (mounted) {
        Fluttertoast.showToast(msg: "Ошибка входа через Google. Попробуйте позже.", backgroundColor: Colors.red, gravity: ToastGravity.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
     if (_isLoading || _googleSignIn == null) return;
    setState(() => _isLoading = true);

    try {
      final account = await _googleSignIn?.signIn();
      if (account != null && mounted) {
        await _handleGoogleSignIn(account);
      }
    } catch (e) {
      print('Google Sign In Error: $e');
      if (mounted) {
        Fluttertoast.showToast(msg: "Не удалось войти через Google", backgroundColor: Colors.red, gravity: ToastGravity.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
     if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
         if (mounted) {
          Fluttertoast.showToast(msg: "Вход выполнен успешно!", gravity: ToastGravity.BOTTOM);
        }
      } else {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
         await userCredential.user!.sendEmailVerification();

        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'nickname': userCredential.user!.email!.split('@')[0].toLowerCase(),
          'photoUrl': '',
          'bio': '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Fluttertoast.showToast(
            msg: "Аккаунт создан! Подтвердите email",
            gravity: ToastGravity.BOTTOM,
            toastLength: Toast.LENGTH_LONG,
           );
          await FirebaseAuth.instance.signOut();

          setState(() {
            isLogin = true;
            _emailController.clear();
            _passwordController.clear();
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Ошибка авторизации";
      switch (e.code) {
        case 'email-already-in-use': msg = "Этот email уже используется"; break;
        case 'weak-password': msg = "Слишком слабый пароль (минимум 6 символов)"; break;
        case 'user-not-found': msg = "Пользователь не найден"; break;
        case 'wrong-password': msg = "Неверный пароль"; break;
        case 'invalid-email': msg = "Неверный формат email"; break;
        case 'user-disabled': msg = "Аккаунт отключен"; break;
        case 'too-many-requests': msg = "Слишком много попыток. Попробуйте позже"; break;
      }
      if (mounted) {
        Fluttertoast.showToast(msg: msg, backgroundColor: Colors.red, gravity: ToastGravity.BOTTOM, toastLength: Toast.LENGTH_LONG);
      }
    } catch (e) {
      print('Auth Error: $e');
      if (mounted) {
        Fluttertoast.showToast(msg: "Произошла ошибка: ${e.toString().split('\n').first}", backgroundColor: Colors.red, gravity: ToastGravity.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? Colors.grey.shade50 : const Color(0xFF0F0F0F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Анимированная иконка
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.blue,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    Text(
                      isLogin ? 'Добро пожаловать!' : 'Создать аккаунт',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isLight ? Colors.black : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLogin ? 'Войдите чтобы продолжить' : 'Зарегистрируйтесь чтобы начать общение',
                      style: TextStyle(
                        fontSize: 14,
                        color: isLight ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 40),

                                        // Поле Email
                    AnimatedOpacity(
                      opacity: _fadeAnimation.value,
                      duration: const Duration(milliseconds: 400),
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.black), // ← всегда чёрный
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(
                            color: isLight ? Colors.grey[700] : Colors.grey[400],
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: isLight ? Colors.grey[700] : Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: isLight ? Colors.white : Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isLight ? Colors.grey[300]! : Colors.grey[700]!,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите email';
                          if (!EmailValidator.validate(value)) return 'Неверный формат email';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Поле Пароль
                    AnimatedOpacity(
                      opacity: _fadeAnimation.value,
                      duration: const Duration(milliseconds: 500),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.black), // ← всегда чёрный
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          labelStyle: TextStyle(
                            color: isLight ? Colors.grey[700] : Colors.grey[400],
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: isLight ? Colors.grey[700] : Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: isLight ? Colors.white : Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isLight ? Colors.grey[300]! : Colors.grey[700]!,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Введите пароль';
                          if (value.length < 6) return 'Пароль должен содержать минимум 6 символов';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Кнопка входа / регистрации
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isLogin ? 'Войти' : 'Зарегистрироваться', style: const TextStyle(fontSize: 16)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          isLogin = !isLogin;
                          _formKey.currentState?.reset();
                        });
                      },
                      child: Text(
                        isLogin ? 'Нет аккаунта? Зарегистрироваться' : 'Уже есть аккаунт? Войти',
                        style: TextStyle(fontSize: 14, color: Colors.blue[300]),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Google
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Продолжить с Google'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isLight ? Colors.grey[300]! : Colors.grey[700]!),
                          foregroundColor: isLight ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}