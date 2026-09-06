import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:selorize/view/home_view.dart';
import 'package:selorize/view/signup_view.dart';
import 'package:selorize/view_model/auth_viewmodel.dart';
import 'package:provider/provider.dart';
import './forgot_password_view.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _step = 0;
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _blankFocusNode = FocusNode();

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _blankFocusNode.dispose();

    super.dispose();
  }

  void _clearForm() {
    FocusManager.instance.primaryFocus?.unfocus();

    _mobileController.clear();
    _otpController.clear();

    setState(() => _step = 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_blankFocusNode);
    });
  }

  Future<void> _handleRequestOtp() async {
    final mobile = _mobileController.text.trim();

    if (mobile.isEmpty || mobile.length < 10) {
      _showSnack('Please enter a valid 10-digit mobile number', isError: true);
      return;
    }
    
    final vm = context.read<AuthViewModel>();
    final success = await vm.requestLoginOtp(mobile);
    if (!mounted) return;

    if (success) {
      _showSnack(vm.successMessage ?? 'OTP sent successfully');
      setState(() => _step = 1);
    } else {
      final message = vm.errorMessage ?? 'Failed to send OTP. Please try again.';
      if (_looksLikeMissingAccount(message)) {
        _showCreateAccountPrompt();
      } else {
        _showSnack(message, isError: true);
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showSnack('Please enter the OTP', isError: true);
      return;
    }

    final vm = context.read<AuthViewModel>();
    final success = await vm.verifyLoginOtp(otp);
    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _showSnack('Wrong OTP', isError: true);
    }
  }

  bool _looksLikeMissingAccount(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('not found') ||
        normalized.contains('not registered') ||
        normalized.contains('no user') ||
        normalized.contains('user does not exist') ||
        normalized.contains('account does not exist') ||
        normalized.contains('id not found') ||
        normalized.contains('user id');
  }

  Future<void> _showCreateAccountPrompt() async {
    final mobile = _mobileController.text.trim();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Account not found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This mobile number is not registered yet. Create an account to continue.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey.shade500,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignUpScreen(initialMobile: mobile),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Create Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Try another login',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _handleBack() {
    if (FocusManager.instance.primaryFocus != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (_step == 1) {
      setState(() => _step = 0);
      return;
    }
    _goHome();
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFF),
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              Positioned(
                top: -100,
                right: -50,
                child: _decorativeCircle(
                  350,
                  const Color(0xFF6366F1).withOpacity(0.07),
                ),
              ),
              Positioned(
                top: 200,
                left: -80,
                child: _decorativeCircle(
                  250,
                  const Color(0xFFD946EF).withOpacity(0.05),
                ),
              ),
              Positioned(
                bottom: -50,
                right: -20,
                child: _decorativeCircle(
                  200,
                  const Color(0xFF4A78A8).withOpacity(0.06),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 720;
                    final topGap = compact ? 10.0 : 18.0;
                    final titleGap = compact ? 12.0 : 16.0;
                    final formGap = compact ? 14.0 : 20.0;

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: topGap),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _guestAccessButton(),
                              ),
                              SizedBox(height: compact ? 10 : 18),
                              Center(child: _buildLogo(compact: compact)),
                              SizedBox(height: titleGap),

                              Center(
                                child: Text(
                                  "Welcome Back",
                                  style: TextStyle(
                                    fontSize: compact ? 28 : 32,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  "Sign in to continue selling and tracking devices.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: compact ? 13 : 14,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),

                              SizedBox(height: formGap),
                              Container(
                                padding: EdgeInsets.all(compact ? 14 : 18),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.96),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0F172A,
                                      ).withOpacity(0.08),
                                      blurRadius: 28,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    if (_step == 0)
                                      _inputField(
                                        controller: _mobileController,
                                        label: "Mobile Number",
                                        hint: "10-digit mobile number",
                                        icon: Icons.phone_android_rounded,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(10),
                                        ],
                                      ),
                                    if (_step == 1) ...[
                                      _inputField(
                                        controller: _otpController,
                                        label: "OTP",
                                        hint: "Enter OTP",
                                        icon: Icons.lock_clock_outlined,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(4),
                                        ],
                                        autofillHints: const [AutofillHints.oneTimeCode],
                                        onChanged: (val) {
                                          if (val.length == 4) {
                                            _handleVerifyOtp();
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _handleRequestOtp,
                                          child: const Text(
                                            "Resend OTP",
                                            style: TextStyle(
                                              color: Color(0xFF4F46E5),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    Consumer<AuthViewModel>(
                                      builder: (_, vm, __) => _primaryButton(
                                        text: _step == 0 ? "Send OTP" : "Verify OTP",
                                        isLoading: vm.isLoading,
                                        onPressed: vm.isLoading
                                            ? null
                                            : (_step == 0 ? _handleRequestOtp : _handleVerifyOtp),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: compact ? 14 : 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Colors.grey.shade200,
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      "OR CONTINUE WITH",
                                      style: TextStyle(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Colors.grey.shade200,
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              _socialButton(
                                icon: 'assets/google.png',
                                label: "Continue with Google",
                                onPressed: () async {
                                  final vm = context.read<AuthViewModel>();
                                  final success = await vm.loginWithGoogle(
                                    context,
                                  );
                                  if (!mounted) return;
                                  if (success) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const HomeScreen(),
                                      ),
                                    );
                                  } else if (vm.errorMessage != null) {
                                    _showSnack(vm.errorMessage!, isError: true);
                                  }
                                },
                              ),

                              const Spacer(),

                              Center(
                                child: TextButton(
                                  onPressed: () async {
                                    _clearForm();

                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SignUpScreen(),
                                      ),
                                    );
                                    if (!mounted) return;
                                    _clearForm();
                                  },
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      text: "New here? ",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: "Create Account",
                                          style: TextStyle(
                                            color: Color(0xFF4A78A8),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
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
      ),
    );
  }

  Widget _decorativeCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(color: Colors.transparent),
    ),
  );

  Widget _guestAccessButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _goHome,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 26,
                width: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  size: 16,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Continue as guest',
                style: TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo({bool compact = false}) {
    return Hero(
      tag: 'app_logo',
      child: Container(
        height: compact ? 82 : 94,
        width: compact ? 82 : 94,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Image.asset(
          'assets/selorize_home.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.phone_iphone_rounded,
            color: Color(0xFF4F46E5),
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onToggleVisibility,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    Iterable<String>? autofillHints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF475569),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            autofocus: false,
            obscureText: isPassword && !isPasswordVisible,
            inputFormatters: inputFormatters,
            focusNode: focusNode,
            onChanged: onChanged,
            autofillHints: autofillHints,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final buttonContent = Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const Bone.text(words: 2)
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0,
                ),
              ),
      ),
    );

    return Skeletonizer(
      enabled: isLoading,
      ignoreContainers: true,
      child: buttonContent,
    );
  }

  Widget _socialButton({
    required String icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              icon,
              width: 24,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.g_mobiledata,
                size: 32,
                color: Color(0xFF4285F4),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
