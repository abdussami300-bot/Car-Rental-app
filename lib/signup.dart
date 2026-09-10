import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';

class Signup extends StatelessWidget {

Signup({super.key});
final nameController = TextEditingController();
final emailController = TextEditingController();
final passwordController = TextEditingController();

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFF121212),

appBar: AppBar(
backgroundColor: const Color(0xFF121212),
foregroundColor: Colors.white,
title: const Text("Create Account"),
),

body: SingleChildScrollView(
child: Padding(
padding: const EdgeInsets.all(20),

child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const SizedBox(height: 25),

const Center(
child: Text(
"Create Your Account",
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
"Sign up to start renting cars",
style: TextStyle(
color: Colors.grey,
fontSize: 15,
),
),
),

const SizedBox(height: 35),

const Text(
"Full Name",
style: TextStyle(
color: Colors.white,
fontSize: 15,
),
),

const SizedBox(height: 8),

TextField(
  controller: nameController,
style: const TextStyle(
color: Colors.white,
),
decoration: InputDecoration(
hintText: "Enter your name",
hintStyle: const TextStyle(
color: Colors.grey,
),
prefixIcon: const Icon(
Icons.person,
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
"Email",
style: TextStyle(
color: Colors.white,
fontSize: 15,
),
),

const SizedBox(height: 8),

TextField(
  controller: emailController,
style: const TextStyle(
color: Colors.white,
),
decoration: InputDecoration(
hintText: "Enter your email",
hintStyle: const TextStyle(
color: Colors.grey,
),
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
style: const TextStyle(
color: Colors.white,
),
decoration: InputDecoration(
hintText: "Enter your password",
hintStyle: const TextStyle(
color: Colors.grey,
),
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

const SizedBox(height: 30),

SizedBox(
width: double.infinity,
height: 52,
child: ElevatedButton(
onPressed: () {
  final enteredName = nameController.text.trim();
  final enteredEmail = emailController.text.trim();
  final enteredPassword = passwordController.text;

  if (enteredName.isEmpty || enteredEmail.isEmpty || enteredPassword.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please fill in all fields"),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  }

  name = enteredName;
  email = enteredEmail;
  password = enteredPassword;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Account created successfully! Please login."),
      backgroundColor: AppTheme.primary,
    ),
  );

  Navigator.pop(context);
},
style: ElevatedButton.styleFrom(
backgroundColor: AppTheme.primary,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),
child: const Text(
"Sign Up",
style: TextStyle(
fontSize: 17,
fontWeight: FontWeight.bold,
),
),
),
),

const SizedBox(height: 25),

Center(
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Text(
"Already have an account? ",
style: TextStyle(
color: Colors.grey,
),
),

TextButton(
onPressed: () {Navigator.pop(context);},
child: const Text(
"Login",
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

