
import 'package:flutter/material.dart';
import 'theme.dart';
import 'signup.dart';
import 'home.dart';
import 'user_data.dart';

class LoginPage extends StatelessWidget {
LoginPage({super.key});

final emailController = TextEditingController();
final passwordController = TextEditingController();

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFF121212),

appBar: AppBar(
backgroundColor: const Color(0xFF121212),
foregroundColor: Colors.white,
title: const Text("Login"),
),

body: SingleChildScrollView(
child: Padding(
padding: const EdgeInsets.all(20),

child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const SizedBox(height: 40),

const Center(
child: Text(
"Welcome Back",
style: TextStyle(
color: Colors.white,
fontSize: 28,
fontWeight: FontWeight.bold,
),
),
),

const SizedBox(height: 10),

const Center(
child: Text(
"Login to continue renting cars",
style: TextStyle(
color: Colors.grey,
fontSize: 15,
),
),
),

const SizedBox(height: 40),

const Text(
"Email",
style: TextStyle(
color: Colors.white,
fontSize: 15,
),
),

const SizedBox(height: 8),

TextField(
controller: emailController,
style: const TextStyle(color: Colors.white),
keyboardType: TextInputType.emailAddress,
decoration: InputDecoration(
hintText: "Enter your email",
hintStyle: const TextStyle(color: Colors.grey),
prefixIcon: const Icon(
Icons.email,
color: AppTheme.primary,
),
filled: true,
fillColor: const Color(0xFF1E1E1E),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide.none,
),
),
),

const SizedBox(height: 20),

const Text(
"Password",
style: TextStyle(
color: Colors.white,
fontSize: 15,
),
),

const SizedBox(height: 8),

TextField(
controller: passwordController,
obscureText: true,
style: const TextStyle(color: Colors.white),
decoration: InputDecoration(
hintText: "Enter your password",
hintStyle: const TextStyle(color: Colors.grey),
prefixIcon: const Icon(
Icons.lock,
color: AppTheme.primary,
),
filled: true,
fillColor: const Color(0xFF1E1E1E),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide.none,
),
),
),

const SizedBox(height: 15),

Align(
alignment: Alignment.centerRight,
child: TextButton(
onPressed: () {},
child: const Text(
"Forgot Password?",
style: TextStyle(
color: AppTheme.primaryLight,
),
),
),
),

const SizedBox(height: 15),

SizedBox(
width: double.infinity,
height: 52,

child: ElevatedButton(
onPressed: () {
  final enteredEmail = emailController.text.trim();
  final enteredPassword = passwordController.text;

  if (enteredEmail.isEmpty || enteredPassword.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please enter both email and password"),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  }

  if ((email.isNotEmpty && enteredEmail == email && enteredPassword == password) ||
      (enteredEmail == "sami@example.com" && enteredPassword == "123")) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          name: name.isNotEmpty ? name : "Sami",
          email: enteredEmail,
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Invalid email or password"),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
},

style: ElevatedButton.styleFrom(
backgroundColor: AppTheme.primary,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),

child: const Text(
"Login",
style: TextStyle(
fontSize: 17,
fontWeight: FontWeight.bold,
),
),
),
),

const SizedBox(height: 16),

// Quick Demo Fill Card
Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  decoration: BoxDecoration(
    color: const Color(0xFF1E1E1E),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
  ),
  child: Row(
    children: [
      const Icon(Icons.key_outlined, color: AppTheme.primary, size: 18),
      const SizedBox(width: 10),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Demo: sami@example.com",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              "Pass: 123",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () {
          emailController.text = "sami@example.com";
          passwordController.text = "123";
        },
        child: const Text(
          "Auto Fill",
          style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    ],
  ),
),

const SizedBox(height: 20),

Center(
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [

const Text(
"Don't have an account? ",
style: TextStyle(
color: Colors.grey,
),
),

TextButton(
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => Signup(),
),
);
},

child: const Text(
"Sign Up",
style: TextStyle(
color: AppTheme.primaryLight,
fontWeight: FontWeight.bold,
),
),
),
],
),
),
],
),
),
),
);
}
}
