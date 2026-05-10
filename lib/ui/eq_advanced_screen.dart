import 'package:flutter/material.dart';
import 'dart:math';
import '../services/player_service.dart';

class EqAdvancedScreen extends StatefulWidget {
  @override
  _EqAdvancedScreenState createState() => _EqAdvancedScreenState();
}

class _EqAdvancedScreenState extends State<EqAdvancedScreen> {
  late List<Map<String, dynamic>> bands;
  final List<String> filterTypes = ['Preamp', 'PK', 'LSC', 'HSC', 'LP', 'HP'];

  @override
  void initState() {
    super.initState();
    bands = PlayerService().eqBands;
  }

  void _applyEQ() {
    PlayerService().applyCurrentEQ();
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
              painter: EqVisualizerPainter(bands, isDark),
              child: Container(),
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
              child: Text('Add New Filter'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBandItem(int index, bool isDark) {
    var band = bands[index];
    bool isPreamp = band['type'] == 'Preamp';

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
                    Text('Filter ${index + 1} ', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
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
                          setState(() {
                            band['type'] = newValue;
                            if (newValue == 'Preamp') {
                              band['fc'] = 0.0;
                              band['q'] = 0.0;
                            } else if (band['fc'] == 0.0) {
                              band['fc'] = 1000.0;
                              band['q'] = 1.41;
                            }
                          });
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
            if (!isPreamp)
              _buildSlider('Freq: ${band['fc'].toInt()} Hz', (band['fc'] as num).toDouble(), 20, 20000, (v) {
                setState(() => band['fc'] = v);
                _applyEQ();
              }, isDark),
            if (band['type'] != 'LP' && band['type'] != 'HP') 
              _buildSlider('Gain: ${(band['gain'] as num).toStringAsFixed(1)} dB', (band['gain'] as num).toDouble(), -20, 20, (v) {
                setState(() => band['gain'] = v);
                _applyEQ();
              }, isDark),
            if (!isPreamp)
              _buildSlider('Q: ${(band['q'] as num).toStringAsFixed(2)}', (band['q'] as num).toDouble(), 0.1, 10, (v) {
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
    String content = "";
    for (var b in bands) {
      if (b['type'] == 'Preamp') {
        content += "Preamp: ${(b['gain'] as num).toStringAsFixed(1)} dB\n";
      } else {
        String apoType = "ON PK";
        if (b['type'] == 'LSC') apoType = "ON LSC";
        else if (b['type'] == 'HSC') apoType = "ON HSC";
        else if (b['type'] == 'LP') apoType = "ON LP";
        else if (b['type'] == 'HP') apoType = "ON HP";
        
        content += "Filter: $apoType Fc ${(b['fc'] as num).toInt()} Hz Gain ${(b['gain'] as num).toStringAsFixed(1)} dB Q ${(b['q'] as num).toStringAsFixed(2)}\n";
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('APO Profile Generated')));
    print(content);
  }
}

class EqVisualizerPainter extends CustomPainter {
  final List<Map<String, dynamic>> bands;
  final bool isDark;

  EqVisualizerPainter(this.bands, this.isDark);

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

    double preamp = 0.0;
    for (var b in bands) {
      if (b['type'] == 'Preamp') preamp += (b['gain'] as num).toDouble();
    }

    for (double x = 0; x <= size.width; x++) {
      double logf = logMin + (x / size.width) * (logMax - logMin);
      double freq = exp(logf);

      double totalGainDb = preamp;
      for (var band in bands) {
        String type = band['type'] ?? 'PK';
        if (type == 'Preamp') continue;

        double fc = (band['fc'] as num).toDouble();
        double gain = (band['gain'] as num).toDouble();
        double q = (band['q'] as num).toDouble();

        if (fc <= 0) continue;
        
        // Approximate visualization magnitude response formulas (not mathematically exact to APO/biquads, just for UI feedback)
        double w0 = freq / fc;
        if (type == 'PK') {
          double a = pow(10.0, gain / 40.0).toDouble();
          double numVal = 1.0 + pow(w0 - 1.0 / w0, 2) * pow(q, 2) * pow(a, 2);
          double denVal = 1.0 + pow(w0 - 1.0 / w0, 2) * pow(q, 2) / pow(a, 2);
          if (denVal != 0) {
            double db = 10 * log10(numVal / denVal);
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
