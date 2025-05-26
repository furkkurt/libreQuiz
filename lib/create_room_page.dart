import 'package:flutter/material.dart';

class CreateRoomPage extends StatefulWidget {
  // ... (existing code)
  @override
  _CreateRoomPageState createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  int _timeLimit = 15;

  @override
  Widget build(BuildContext context) {
    // ... (existing code)
    return Scaffold(
      // ... (existing code)
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (existing code)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Time Limit per Question',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimeButton('15 sec', 15),
                    _buildTimeButton('30 sec', 30),
                    _buildTimeButton('60 sec', 60),
                    _buildTimeButton('120 sec', 120),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(String text, int seconds) {
    final isSelected = _timeLimit == seconds;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () => setState(() => _timeLimit = seconds),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.deepOrange : Colors.grey[800],
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
} 