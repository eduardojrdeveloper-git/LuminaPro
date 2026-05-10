import 'package:flutter/material.dart';

class EqAdvancedScreen extends StatefulWidget {
  @override
  _EqAdvancedScreenState createState() => _EqAdvancedScreenState();
}

class _EqAdvancedScreenState extends State<EqAdvancedScreen> {
  List<Map<String, dynamic>> bands = [
    {'fc': 31.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'},
    {'fc': 62.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'},
    {'fc': 125.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced PEQ'),
        actions: [
          IconButton(icon: Icon(Icons.save), onPressed: _exportApoProfile),
          IconButton(icon: Icon(Icons.file_upload), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Graphic Visualization Placeholder
          Container(
            height: 200,
            color: Color(0xFF1C1C1E),
            child: Center(child: Text('Response Curve Visualization', style: TextStyle(color: Colors.grey))),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: bands.length,
              itemBuilder: (context, index) {
                return _buildBandItem(index);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => setState(() => bands.add({'fc': 1000.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'})),
              child: Text('Add New Band'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBandItem(int index) {
    var band = bands[index];
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Color(0xFF2C2C2E),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Band ${index + 1} (${band['type']})', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => bands.removeAt(index))),
              ],
            ),
            _buildSlider('Freq: ${band['fc'].toInt()} Hz', band['fc'], 20, 20000, (v) => setState(() => band['fc'] = v)),
            _buildSlider('Gain: ${band['gain'].toStringAsFixed(1)} dB', band['gain'], -20, 20, (v) => setState(() => band['gain'] = v)),
            _buildSlider('Q: ${band['q'].toStringAsFixed(2)}', band['q'], 0.1, 10, (v) => setState(() => band['q'] = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChange) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12))),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChange, activeColor: Colors.pinkAccent)),
      ],
    );
  }

  void _exportApoProfile() {
    String content = "Preamp: -6.0 dB\n";
    for (var b in bands) {
      content += "Filter: ON ${b['type']} Fc ${b['fc'].toInt()} Hz Gain ${b['gain'].toStringAsFixed(1)} dB Q ${b['q'].toStringAsFixed(2)}\n";
    }
    // TODO: Use share or file_picker to save as .txt
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('APO Profile Generated')));
    print(content);
  }
}
