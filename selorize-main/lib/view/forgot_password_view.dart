import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selorize/view_model/auth_viewmodel.dart';
import 'package:provider/provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0; // 0 = send otp, 1 = verify otp, 2 = reset password

  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final _emailMobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _otpFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();

  String? _userId;
  final _forgotPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailMobileController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    final value = _emailMobileController.text.trim();

    if (value.isEmpty) {
      _showSnack('Please enter email or mobile number', isError: true);
      return;
    }

    final vm = context.read<AuthViewModel>();
    final success = await vm.sendForgotOtp(value);

    if (!mounted) return;

    if (success) {
      _userId = vm.forgotUserId;
      _showSnack(vm.successMessage ?? 'OTP sent successfully');

      setState(() => _step = 1);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_otpFocusNode);
      });
    } else {
      _showSnack(vm.errorMessage ?? 'Failed to send OTP', isError: true);
    }
  }

  void _handleVerifyOtp() {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _showSnack('Please enter OTP', isError: true);
      return;
    }

    final vm = context.read<AuthViewModel>();
    final verified = vm.verifyForgotOtp(otp);

    if (verified) {
      _showSnack(vm.successMessage ?? 'OTP verified successfully');
      setState(() => _step = 2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_newPasswordFocusNode);
      });
    } else {
      _showSnack('Wrong OTP', isError: true);
    }
  }

  Future<void> _handleUpdatePassword() async {
    final id = _userId;
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (id == null || id.isEmpty) {
      _showSnack('User id not found. Please resend OTP.', isError: true);
      setState(() => _step = 0);
      return;
    }

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnack('Please enter new password', isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnack('Passwords do not match', isError: true);
      return;
    }

    final vm = context.read<AuthViewModel>();
    final success = await vm.updatePassword(
      id: id,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    if (!mounted) return;

    if (success) {
      _showSnack(vm.successMessage ?? 'Password updated successfully');
      Navigator.pop(context);
    } else {
      _showSnack(vm.errorMessage ?? 'Password update failed', isError: true);
    }
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

  String get _title {
    if (_step == 0) return 'Forgot Password?';
    if (_step == 1) return 'Verify OTP';
    return 'Reset Password';
  }

  String get _subtitle {
    if (_step == 0) {
      return "Don't worry! Enter the mobile number associated with your account.";
    }
    if (_step == 1) {
      return 'Enter the OTP sent to ${_emailMobileController.text.trim()}.';
    }
    return 'Create a new password for your account.';
  }

  String get _buttonText {
    if (_step == 0) return 'Send Code';
    if (_step == 1) return 'Verify OTP';
    return 'Update Password';
  }

  VoidCallback? _buttonAction(bool isLoading) {
    if (isLoading) return null;
    if (_step == 0) return _handleSendCode;
    if (_step == 1) return _handleVerifyOtp;
    return _handleUpdatePassword;
  }

  void _handleBack() {
    FocusScope.of(context).unfocus();

    if (_step > 0) {
      setState(() => _step--);
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
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
                top: -150,
                left: -100,
                child: _buildDecorativeCircle(
                  400,
                  const Color(0xFF4A78A8).withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                bottom: -100,
                right: -100,
                child: _buildDecorativeCircle(
                  300,
                  const Color(0xFF4A78A8).withValues(alpha: 0.05),
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
                                  color: Colors.black.withValues(alpha: 0.02),
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

                        const SizedBox(height: 40),

                        Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4A78A8,
                                  ).withValues(alpha: 0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              _step == 2
                                  ? Icons.password_rounded
                                  : Icons.lock_reset_rounded,
                              size: 60,
                              color: const Color(0xFF4A78A8),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF101828),
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _subtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            letterSpacing: 0.1,
                          ),
                        ),

                        const SizedBox(height: 48),

                        if (_step == 0)
                          _buildInputField(
                            controller: _emailMobileController,
                            label: 'Mobile Number',
                            hint: 'e.g. 1234567890',
                            icon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            onChanged: (value) {
                              if (value.length == 10) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_forgotPasswordFocusNode);
                              }
                            },
                          ),
                        if (_step == 1)
                          AutofillGroup(
                            child: _buildInputField(
                              controller: _otpController,
                              focusNode: _otpFocusNode,
                              label: 'OTP',
                              hint: 'Enter OTP',
                              icon: Icons.lock_clock_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              autofillHints: const [AutofillHints.oneTimeCode],
                            ),
                          ),

                        if (_step == 2) ...[
                          _buildInputField(
                            controller: _newPasswordController,
                            focusNode: _newPasswordFocusNode,
                            label: 'New Password',
                            hint: 'Enter new password',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            isPasswordVisible: _isNewPasswordVisible,
                            onToggleVisibility: () {
                              setState(() {
                                _isNewPasswordVisible = !_isNewPasswordVisible;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildInputField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            hint: 'Confirm new password',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            isPasswordVisible: _isConfirmPasswordVisible,
                            onToggleVisibility: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ],

                        const SizedBox(height: 40),

                        Consumer<AuthViewModel>(
                          builder: (_, vm, __) => _buildPrimaryButton(
                            text: _buttonText,
                            isLoading: vm.isLoading,
                            onPressed: _buttonAction(vm.isLoading),
                          ),
                        ),

                        const SizedBox(height: 40),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Remember Password? ',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Color(0xFF4A78A8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
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

  Widget _buildDecorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
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
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            obscureText: isPassword && !isPasswordVisible,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            autofillHints: autofillHints,
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
                      onPressed: onToggleVisibility,
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
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

  Widget _buildPrimaryButton({
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
            color: const Color(0xFF4A78A8).withValues(alpha: 0.25),
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
