import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:selorize/view_model/auth_viewmodel.dart';
import 'package:provider/provider.dart';
import './home_view.dart';
import 'package:flutter/services.dart';

class SignUpScreen extends StatefulWidget {
  final String initialMobile;
  final bool returnToPreviousOnSuccess;
  const SignUpScreen({
    super.key,
    this.initialMobile = '',
    this.returnToPreviousOnSuccess = false,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // 0 = enter mobile  |  1 = enter OTP  |  2 = fill details
  int _step = 0;

  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _blankFocusNode = FocusNode();

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _blankFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _mobileController.text = widget.initialMobile;
  }

  void _clearForm() {
    _dismissKeyboard();
    _mobileController.clear();
    _otpController.clear();
    _nameController.clear();
    _emailController.clear();

    setState(() {
      _step = 0;
    });
  }

  void _handleBack() {
    _dismissKeyboard();

    if (_step > 0) {
      setState(() => _step--);
      return;
    }

    _clearForm();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // Step handlers

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _moveToStep(int step) {
    _dismissKeyboard();
    setState(() => _step = step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_blankFocusNode);
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    });
  }

  Future<void> _handleRequestOtp() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty || mobile.length < 10) {
      _showSnack('Enter a valid 10-digit mobile number', isError: true);
      return;
    }
    final vm = context.read<AuthViewModel>();
    await vm.requestOtp(mobile);
    if (!mounted) return;
    if (vm.errorMessage != null) {
      _showSnack(vm.errorMessage!, isError: true);
    } else {
      _showSnack(vm.successMessage ?? 'OTP sent!');
      _moveToStep(1);
    }
  }

  void _handleVerifyOtp() {
    if (_otpController.text.trim().isEmpty) {
      _showSnack('Please enter the OTP', isError: true);
      return;
    }
    final vm = context.read<AuthViewModel>();
    final verified = vm.verifyOtp(_otpController.text.trim());
    if (verified) {
      _showSnack(vm.successMessage ?? 'OTP verified successfully');
      _moveToStep(2);
    } else {
      _showSnack(
        'Wrong OTP',
        isError: true,
      );
    }
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      _showSnack('Please fill all fields', isError: true);
      return;
    }

    final vm = context.read<AuthViewModel>();
    final success = await vm.signUp(
      mobile: mobile,
      email: email,
      name: name,
    );
    if (!mounted) return;
    if (success) {
      if (widget.returnToPreviousOnSuccess) {
        Navigator.pop(context, true);
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _showErrorDialog(vm.errorMessage ?? 'Sign-up failed. Please try again.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Account Failed'),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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
          backgroundColor: const Color(0xFFFAFBFF),
          body: Stack(
            children: [
              Positioned(
                top: -100,
                left: -100,
                child: _decorativeCircle(
                  350,
                  const Color(0xFF4A78A8).withOpacity(0.07),
                ),
              ),
              Positioned(
                bottom: -50,
                right: -50,
                child: _decorativeCircle(
                  250,
                  const Color(0xFF4A78A8).withOpacity(0.04),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Back button
                        GestureDetector(
                          onTap: _handleBack,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Step indicator dots
                        Row(
                          children: List.generate(
                            3,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              height: 6,
                              width: _step == i ? 24 : 6,
                              decoration: BoxDecoration(
                                color: _step == i
                                    ? const Color(0xFF4A78A8)
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          _step == 0
                              ? "Create Account"
                              : _step == 1
                              ? "Verify OTP"
                              : "Complete Profile",
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF101828),
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _step == 0
                              ? "Enter your mobile number to get started."
                              : _step == 1
                              ? "Enter the OTP sent to +91 ${_mobileController.text}."
                              : "Fill in your details to complete sign-up.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Step 0: Mobile
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
                            onChanged: (value) {
                              if (value.length == 10) {
                                FocusScope.of(context).unfocus();
                              }
                            },
                          ),

                        // Step 1: OTP
                        if (_step == 1) ...[
                          AutofillGroup(
                            child: _inputField(
                              controller: _otpController,
                              label: "OTP",
                              hint: "Enter OTP received on your mobile",
                              icon: Icons.lock_clock_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              autofillHints: const [AutofillHints.oneTimeCode],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleRequestOtp,
                              child: const Text(
                                "Resend OTP",
                                style: TextStyle(
                                  color: Color(0xFF4A78A8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Step 2: Details
                        if (_step == 2) ...[
                          _inputField(
                            controller: _nameController,
                            label: "Full Name",
                            hint: "e.g. John Doe",
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 20),
                          _inputField(
                            controller: _emailController,
                            label: "Email Address",
                            hint: "e.g. john@example.com",
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],

                        const SizedBox(height: 40),

                        // CTA button
                        Consumer<AuthViewModel>(
                          builder: (_, vm, __) => _primaryButton(
                            text: _step == 0
                                ? "Send OTP"
                                : _step == 1
                                ? "Verify OTP"
                                : "Create Account",
                            isLoading: vm.isLoading,
                            onPressed: vm.isLoading
                                ? null
                                : _step == 0
                                ? _handleRequestOtp
                                : _step == 1
                                ? _handleVerifyOtp
                                : _handleSignUp,
                          ),
                        ),

                        const SizedBox(height: 32),

                        Center(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account? ",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      _clearForm();
                                      FocusScope.of(context).unfocus();
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      "Login",
                                      style: TextStyle(
                                        color: Color(0xFF4A78A8),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  "By signing up, you agree to our Terms of Service and Privacy Policy.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers

  Widget _decorativeCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(color: Colors.transparent),
    ),
  );

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
    ValueChanged<String>? onChanged,
    Iterable<String>? autofillHints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF344054),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            autofocus: false,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            autofillHints: autofillHints,
            obscureText: isPassword && !isPasswordVisible,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF4A78A8), size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
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
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A78A8), Color(0xFF2E4E6D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A78A8).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}
