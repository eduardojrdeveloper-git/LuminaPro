import 'package:flutter/material.dart';
import 'dart:math';
import '../services/player_service.dart';

class EqAdvancedScreen extends StatefulWidget {
  @override
  _EqAdvancedScreenState createState() => _EqAdvancedScreenState();
}

class _EqAdvancedScreenState extends State<EqAdvancedScreen> {
  double preamp = 0.0;
  List<Map<String, dynamic>> bands = [
    {'fc': 31.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'},
    {'fc': 250.0, 'gain': 0.0, 'q': 1.41, 'type': 'LSC'},
    {'fc': 1000.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'},
    {'fc': 8000.0, 'gain': 0.0, 'q': 1.41, 'type': 'HSC'},
  ];

  final List<String> filterTypes = ['PK', 'LSC', 'HSC', 'LP', 'HP'];

  void _applyEQ() {
    PlayerService().updateEQ(bands);
  }

  void _applyPreamp() {
    PlayerService().updatePreamp(preamp);
  }

  @override
  void initState() {
    super.initState();
    _applyEQ();
    _applyPreamp();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Parametric EQ', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(icon: Icon(Icons.save, color: isDark ? Colors.white : Colors.black), onPressed: _exportApoProfile),
        ],
      ),
      body: Column(
        children: [
          // Graphic Visualization
          Container(
            height: 200,
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Color(0xFF1C1C1E) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              painter: EqVisualizerPainter(bands, preamp, isDark),
              child: Container(),
            ),
          ),
          
          // Preamp Control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text('Preamp: ${preamp.toStringAsFixed(1)} dB', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold))),
                Expanded(child: Slider(value: preamp, min: -20, max: 20, onChanged: (v) {
                  setState(() => preamp = v);
                  _applyPreamp();
                }, activeColor: Colors.cyanAccent)),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: bands.length,
              itemBuilder: (context, index) {
                return _buildBandItem(index, isDark);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() => bands.add({'fc': 1000.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'}));
                _applyEQ();
              },
              child: Text('Add New Band'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBandItem(int index, bool isDark) {
    var band = bands[index];
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? Color(0xFF2C2C2E) : Colors.white,
      elevation: isDark ? 0 : 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Band ${index + 1} ', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    DropdownButton<String>(
                      value: band['type'],
                      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                      items: filterTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => band['type'] = newValue);
                          _applyEQ();
                        }
                      },
                    ),
                  ],
                ),
                IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () {
                  setState(() => bands.removeAt(index));
                  _applyEQ();
                }),
              ],
            ),
            _buildSlider('Freq: ${band['fc'].toInt()} Hz', band['fc'], 20, 20000, (v) {
              setState(() => band['fc'] = v);
              _applyEQ();
            }, isDark),
            if (band['type'] != 'LP' && band['type'] != 'HP') 
              _buildSlider('Gain: ${band['gain'].toStringAsFixed(1)} dB', band['gain'], -20, 20, (v) {
                setState(() => band['gain'] = v);
                _applyEQ();
              }, isDark),
            _buildSlider('Q: ${band['q'].toStringAsFixed(2)}', band['q'], 0.1, 10, (v) {
              setState(() => band['q'] = v);
              _applyEQ();
            }, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChange, bool isDark) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87))),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChange, activeColor: Colors.pinkAccent)),
      ],
    );
  }

  void _exportApoProfile() {
    String content = "Preamp: ${preamp.toStringAsFixed(1)} dB\n";
    for (var b in bands) {
      // Basic APO format mapping
      String apoType = "ON PK";
      if (b['type'] == 'LSC') apoType = "ON LSC";
      else if (b['type'] == 'HSC') apoType = "ON HSC";
      else if (b['type'] == 'LP') apoType = "ON LP";
      else if (b['type'] == 'HP') apoType = "ON HP";
      
      content += "Filter: $apoType Fc ${b['fc'].toInt()} Hz Gain ${b['gain'].toStringAsFixed(1)} dB Q ${b['q'].toStringAsFixed(2)}\n";
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('APO Profile Generated')));
    print(content);
  }
}

class EqVisualizerPainter extends CustomPainter {
  final List<Map<String, dynamic>> bands;
  final double preamp;
  final bool isDark;

  EqVisualizerPainter(this.bands, this.preamp, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark ? Colors.white12 : Colors.black12
      ..strokeWidth = 1.0;

    // Draw center zero line
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);

    final curvePaint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool first = true;

    // Calculate approx frequency response curve
    // X-axis: log scale from 20Hz to 20kHz
    double minFreq = 20.0;
    double maxFreq = 20000.0;
    double logMin = log(minFreq);
    double logMax = log(maxFreq);

    for (double x = 0; x <= size.width; x++) {
      double logf = logMin + (x / size.width) * (logMax - logMin);
      double freq = exp(logf);

      double totalGainDb = preamp; // Start with preamp offset
      for (var band in bands) {
        double fc = band['fc'];
        double gain = band['gain'];
        double q = band['q'];
        String type = band['type'] ?? 'PK';

        if (fc <= 0) continue;
        
        // Approximate visualization magnitude response formulas (not mathematically exact to APO/biquads, just for UI feedback)
        double w0 = freq / fc;
        if (type == 'PK') {
          double a = pow(10.0, gain / 40.0).toDouble();
          double num = 1.0 + pow(w0 - 1.0 / w0, 2) * pow(q, 2) * pow(a, 2);
          double den = 1.0 + pow(w0 - 1.0 / w0, 2) * pow(q, 2) / pow(a, 2);
          if (den != 0) {
            double db = 10 * log10(num / den);
            if (gain < 0) db = -db;
            totalGainDb += db;
          }
        } else if (type == 'LSC') {
           // Basic shelf approximation
           if (freq < fc) {
              totalGainDb += gain * (1 - (freq/fc)); // Smooth out
           }
        } else if (type == 'HSC') {
           if (freq > fc) {
              totalGainDb += gain * (1 - (fc/freq)); // Smooth out
           }
        } else if (type == 'LP') {
           if (freq > fc) {
               totalGainDb -= 12.0 * log2(freq/fc); // Approximate 12dB/octave rolloff
           }
        } else if (type == 'HP') {
           if (freq < fc) {
               totalGainDb -= 12.0 * log2(fc/freq); // Approximate 12dB/octave rolloff
           }
        }
      }

      // Map gain to Y axis. +/- 24dB max range.
      double dbRange = 24.0;
      double y = size.height / 2 - (totalGainDb / dbRange) * (size.height / 2);
      
      // Clamp Y
      y = max(0, min(size.height, y));

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, curvePaint);
  }

  // math helpers
  double log10(num x) => log(x) / ln10;
  double log2(num x) => log(x) / ln2;

  @override
  bool shouldRepaint(covariant EqVisualizerPainter oldDelegate) {
    return true; // Always repaint
  }
}

