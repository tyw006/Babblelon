
import 'package:flutter/material.dart';

class MainWorldScreen extends StatefulWidget {
  const MainWorldScreen({super.key});

  @override
  State<MainWorldScreen> createState() => _MainWorldScreenState();
}

class _MainWorldScreenState extends State<MainWorldScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blue.shade400,
                  Colors.blue.shade600,
                  Colors.blue.shade800,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
