import 'package:flutter/material.dart';

class EqScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Lumina Pro - PEQ', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bit-Perfect Audio Engine', style: TextStyle(color: Colors.white70, fontSize: 18)),
            SizedBox(height: 40),
            // Placeholder for EQ Curve Visualization
            Container(
              height: 200,
              width: double.infinity,
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(
                painter: EqCurvePainter(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                // TODO: Implement document picker to read APO .txt file
              },
              child: Text('Load Equalizer APO Profile', style: TextStyle(color: Colors.black)),
            )
          ],
        ),
      ),
    );
  }
}

class EqCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height / 2);
    // Placeholder EQ magnitude curve visualization
    path.quadraticBezierTo(size.width / 4, size.height / 4, size.width / 2, size.height / 2);
    path.quadraticBezierTo(3 * size.width / 4, 3 * size.height / 4, size.width, size.height / 2);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}