import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/player_service.dart';
import '../main.dart' show LuminaColors;

// ── EQ Presets ────────────────────────────────────────────────────────────────
class EqPreset {
  final String name;
  final List<Map<String, dynamic>> bands;
  const EqPreset(this.name, this.bands);
}

final List<EqPreset> kEqPresets = [
  EqPreset('Flat', [
    {'fc': 1000.0, 'gain': 0.0, 'q': 1.41, 'type': 'Preamp'},
  ]),
  EqPreset('Bass Boost', [
    {'fc': 1000.0, 'gain': -2.0, 'q': 1.41, 'type': 'Preamp'},
    {'fc': 60.0, 'gain': 6.0, 'q': 0.7, 'type': 'PK'},
    {'fc': 200.0, 'gain': 3.0, 'q': 1.0, 'type': 'PK'},
  ]),
  EqPreset('Vocal', [
    {'fc': 1000.0, 'gain': -2.0, 'q': 1.41, 'type': 'Preamp'},
    {'fc': 1000.0, 'gain': 4.0, 'q': 1.5, 'type': 'PK'},
    {'fc': 3000.0, 'gain': 3.0, 'q': 1.2, 'type': 'PK'},
    {'fc': 100.0, 'gain': -3.0, 'q': 0.8, 'type': 'HSC'},
  ]),
];

class EqAdvancedScreen extends StatefulWidget {
  const EqAdvancedScreen({super.key});

  @override
  State<EqAdvancedScreen> createState() => _EqAdvancedScreenState();
}

class _EqAdvancedScreenState extends State<EqAdvancedScreen> {
  final PlayerService _ps = PlayerService();
  late List<Map<String, dynamic>> _bands;
  final List<String> _filterTypes = ['Preamp', 'PK', 'LSC', 'HSC', 'LP', 'HP'];
  String? _activePreset;

  // Use a ValueNotifier to trigger real-time repaints of the painter
  late final ValueNotifier<List<Map<String, dynamic>>> _bandsNotifier;

  @override
  void initState() {
    super.initState();
    _bands = List.from(_ps.eqBands.map((b) => Map<String, dynamic>.from(b)));
    _bandsNotifier = ValueNotifier(_bands);
  }

  void _onBandChanged() {
    _bandsNotifier.value = List.from(_bands); // Trigger repaint
    _ps.eqBands = _bands;
    _ps.applyCurrentEQ();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text('Parametric EQ', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Real-time EQ Visualizer ──────────────────────────────────
            Container(
              height: 200,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? LuminaColors.bg1 : LuminaColors.lightBg1,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: _bandsNotifier,
                  builder: (_, bands, __) => CustomPaint(
                    painter: EqVisualizerPainter(bands, isDark),
                    child: Container(),
                  ),
                ),
              ),
            ),

            // ── Bands List ───────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _bands.length,
                itemBuilder: (_, i) => _buildBandRow(_bands[i], i, isDark),
              ),
            ),
            
            // Add band button
            Padding(
              padding: const EdgeInsets.all(20),
              child: CupertinoButton(
                color: LuminaColors.accent,
                borderRadius: BorderRadius.circular(12),
                child: const Text('Add Filter Band', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () {
                  setState(() {
                    _bands.add({'fc': 1000.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'});
                    _onBandChanged();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBandRow(Map<String, dynamic> band, int index, bool isDark) {
    final isPreamp = band['type'] == 'Preamp';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? LuminaColors.bg1 : LuminaColors.lightBg1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(band['type'], style: const TextStyle(fontWeight: FontWeight.bold, color: LuminaColors.accent)),
              const Spacer(),
              if (!isPreamp) Text('${band['fc'].toInt()} Hz', style: const TextStyle(fontSize: 12, color: LuminaColors.labelSecondary)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _bands.removeAt(index);
                    _onBandChanged();
                  });
                },
                child: const Icon(CupertinoIcons.trash, size: 18, color: LuminaColors.destructive),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isPreamp)
            _buildSlider('Freq', band['fc'], 20, 20000, (v) {
              setState(() { band['fc'] = v; _onBandChanged(); });
            }),
          _buildSlider('Gain', band['gain'], -20, 20, (v) {
            setState(() { band['gain'] = v; _onBandChanged(); });
          }),
          if (!isPreamp)
            _buildSlider('Q', band['q'], 0.1, 10, (v) {
              setState(() { band['q'] = v; _onBandChanged(); });
            }),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label, style: const TextStyle(fontSize: 12, color: LuminaColors.labelSecondary))),
        Expanded(child: CupertinoSlider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged)),
        SizedBox(width: 45, child: Text(value.toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}

class EqVisualizerPainter extends CustomPainter {
  final List<Map<String, dynamic>> bands;
  final bool isDark;
  EqVisualizerPainter(this.bands, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = isDark ? Colors.white10 : Colors.black.withOpacity(0.05)..strokeWidth = 0.5;
    for (final db in [-12.0, -6.0, 0.0, 6.0, 12.0]) {
      final y = _dbToY(db, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double preamp = 0.0;
    for (var b in bands) if (b['type'] == 'Preamp') preamp += b['gain'];

    final path = Path();
    final fillPath = Path();
    bool first = true;
    
    for (double x = 0; x <= size.width; x += 2) {
      final freq = exp(log(20.0) + (x / size.width) * (log(20000.0) - log(20.0)));
      double totalDb = preamp;

      for (var band in bands) {
        if (band['type'] == 'Preamp') continue;
        totalDb += _calcGain(band, freq);
      }

      final y = _dbToY(totalDb, size);
      if (first) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [LuminaColors.accent.withOpacity(0.3), LuminaColors.accent.withOpacity(0.0)],
    );
    canvas.drawPath(fillPath, Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawPath(path, Paint()..color = LuminaColors.accent..strokeWidth = 3..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
  }

  double _calcGain(Map<String, dynamic> band, double freq) {
    final type = band['type'];
    final fc = band['fc'] as double;
    final gain = band['gain'] as double;
    final q = band['q'] as double;
    if (fc <= 0) return 0;
    final w0 = freq / fc;
    
    if (type == 'PK') {
      final a = pow(10.0, gain / 40.0);
      final n = 1.0 + pow(w0 - 1.0/w0, 2) * pow(q, 2) * pow(a, 2);
      final d = 1.0 + pow(w0 - 1.0/w0, 2) * pow(q, 2) / pow(a, 2);
      return 10 * log(n/d) / ln10;
    }
    return 0; // Simplified for other types for now
  }

  double _dbToY(double db, Size size) => (size.height / 2) - (db / 20.0) * (size.height / 2);

  @override
  bool shouldRepaint(covariant EqVisualizerPainter old) => true; // Always repaint for real-time
}
