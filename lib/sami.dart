import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext _context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );

  }
}



class LoginPage extends StatelessWidget {

  const LoginPage({super.key});


  @override
  Widget build(BuildContext _context) {

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        leading: Icon(Icons.menu),
        title: Text("My Profile" ,style: TextStyle(fontWeight: FontWeight.bold),),
        actions: [
          Icon(Icons.more_vert)
        ],

      ),
      body: Container(
        padding: EdgeInsets.all(10.0),
        child:
        Center(child:Column(children: [ CircleAvatar( radius: 80,
          foregroundImage: AssetImage("icon.png",
          ),
        ),
          Text("Abc Xyz",style:
          TextStyle(fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          ),
          Text("abcxyz@gmail.com",style:
          TextStyle(fontSize: 18,
            color: Colors.grey,
            fontWeight: FontWeight.w900,
          ),
          ),
          SizedBox(height: 20),
          ElevatedButton(onPressed: (){}, child:
          Text("Edit Profile"),)
        ],
        ),
        ),
      ),
    );
  }
}