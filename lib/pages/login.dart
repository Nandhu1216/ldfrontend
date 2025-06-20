import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  bool _otpSent = false;
  bool _isLoading = false;

  Future<bool> _isPhoneAllowed(String fullPhoneNumber) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Appusers')
          .doc('Number')
          .get();

      final List<dynamic>? numbers = doc.data()?['mobile'];
      return numbers != null && numbers.contains(fullPhoneNumber);
    } catch (e) {
      debugPrint('Error checking phone: $e');
      return false;
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty || phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fullPhone = '+91$phone';
    final isAllowed = await _isPhoneAllowed(fullPhone);

    if (!isAllowed) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This number is not authorized to login')),
      );
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        _navigateToHome();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${e.message}')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _otpSent = true;
          _verificationId = verificationId;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (_verificationId == null || otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      _navigateToHome();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please try again.')),
      );
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login with OTP'),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                ),
                enabled: !_otpSent,
              ),
              const SizedBox(height: 20),
              if (_otpSent)
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _otpSent ? _verifyOtp : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
