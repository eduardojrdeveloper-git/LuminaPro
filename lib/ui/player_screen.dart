import 'package:flutter/material.dart';

class PlayerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, Colors.black],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Spacer(),
          // Album Art with Shadow
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))
                ],
                image: DecorationImage(
                  image: NetworkImage('https://via.placeholder.com/400'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Song Title', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('Artist Name', style: TextStyle(fontSize: 20, color: Colors.pinkAccent)),
                ],
              ),
              Icon(Icons.more_horiz, color: Colors.white),
            ],
          ),
          SizedBox(height: 30),
          // Progress bar
          Slider(
            value: 0.3,
            onChanged: (v) {},
            activeColor: Colors.white,
            inactiveColor: Colors.white24,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1:02', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text('-2:45', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          SizedBox(height: 30),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.skip_previous, size: 48),
              Icon(Icons.play_arrow, size: 72),
              Icon(Icons.skip_next, size: 48),
            ],
          ),
          Spacer(),
          // Bottom controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.volume_down, color: Colors.white54),
              Expanded(
                child: Slider(value: 0.7, onChanged: (v) {}, activeColor: Colors.white54),
              ),
              Icon(Icons.volume_up, color: Colors.white54),
            ],
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
