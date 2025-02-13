import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:phase_1_app/utils/config.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool obsecurePass = true;
  String loginMessage = "";
  Color messageColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            cursorColor: Config.primaryColor,
            decoration: InputDecoration(
              hintText: 'Email Address',
              labelText: 'Email',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.email_outlined, color: Config.primaryColor),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          SizedBox(height: 16),  // Use SizedBox for spacing
          
          // Password Field
          TextFormField(
            controller: _passController,
            keyboardType: TextInputType.visiblePassword,
            cursorColor: Config.primaryColor,
            obscureText: obsecurePass,
            decoration: InputDecoration(
              hintText: 'Password',
              labelText: 'Password',
              alignLabelWithHint: true,
              prefixIcon:
                  const Icon(Icons.lock_outline, color: Config.primaryColor),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    obsecurePass = !obsecurePass;
                  });
                },
                icon: obsecurePass
                    ? const Icon(
                        Icons.visibility_off_outlined,
                        color: Colors.black38,
                      )
                    : const Icon(
                        Icons.visibility_outlined,
                        color: Config.primaryColor,
                      ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters long';
              }
              return null;
            },
          ),
          SizedBox(height: 16),  // Use SizedBox for spacing
          
          // Login Button
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final email = _emailController.text.trim();
                final password = _passController.text.trim();

                const url = 'http://192.168.29.185:5001/login'; // Flask endpoint

                try {
                  final response = await http.post(
                    Uri.parse(url),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'email': email,
                      'password': password,
                    }),
                  );

                  if (response.statusCode == 200) {
                    final result = jsonDecode(response.body);

                    if (result['success']) {
                      setState(() {
                        loginMessage = "Login successful!";
                        messageColor = Colors.green;
                      });
                      Navigator.of(context).pushReplacementNamed('main');
                    } else {
                      setState(() {
                        loginMessage = "Invalid credentials. Try again.";
                        messageColor = Colors.red;
                      });
                    }
                  } else {
                    setState(() {
                      loginMessage = "Server error: ${response.statusCode}";
                      messageColor = Colors.red;
                    });
                  }
                } catch (e) {
                  setState(() {
                    loginMessage = "Error: $e";
                    messageColor = Colors.red;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Config.primaryColor,
            ),
            child: const Text('Sign In'),
          ),
          SizedBox(height: 16),  // Use SizedBox for spacing
          
          // Display Login Status Message
          Text(
            loginMessage,
            style: TextStyle(color: messageColor),
          ),
        ],
      ),
    );
  }
}
