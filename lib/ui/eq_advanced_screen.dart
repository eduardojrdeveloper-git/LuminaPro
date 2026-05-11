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
  
  // Use a ValueNotifier to trigger real-time repaints of the painter
  late final ValueNotifier<List<Map<String, dynamic>>> _bandsNotifier;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

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

  void _addBand() {
    final newBand = {'fc': 1000.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'};
    setState(() {
      _bands.add(newBand);
      _listKey.currentState?.insertItem(_bands.length - 1);
      _onBandChanged();
    });
  }

  void _removeBand(int index) {
    final removed = _bands[index];
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildAnimatedBandRow(removed, animation, index, Theme.of(context).brightness == Brightness.dark),
    );
    setState(() {
      _bands.removeAt(index);
      _onBandChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text('Parametric EQ', 
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          )
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _addBand,
          child: const Icon(CupertinoIcons.add_circled, size: 24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Premium Real-time Visualizer ──────────────────────────────
            Container(
              height: 180,
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: _bandsNotifier,
                  builder: (_, bands, __) => CustomPaint(
                    painter: EqVisualizerPainter(bands, isDark),
                    child: Container(),
                  ),
                ),
              ),
            ),

            // ── Animated Bands List ────────────────────────────────────────
            Expanded(
              child: AnimatedList(
                key: _listKey,
                initialItemCount: _bands.length,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index, animation) {
                  return _buildAnimatedBandRow(_bands[index], animation, index, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBandRow(Map<String, dynamic> band, Animation<double> animation, int index, bool isDark) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        child: _buildBandCard(band, index, isDark),
      ),
    );
  }

  Widget _buildBandCard(Map<String, dynamic> band, int index, bool isDark) {
    final isPreamp = band['type'] == 'Preamp';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: LuminaColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  band['type'].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1.0,
                    color: LuminaColors.accent,
                  ),
                ),
              ),
              const Spacer(),
              if (!isPreamp)
                Text(
                  '${band['fc'].toInt()} Hz',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LuminaColors.labelSecondary,
                  ),
                ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _removeBand(index),
                child: const Icon(CupertinoIcons.minus_circle_fill, size: 20, color: LuminaColors.destructive),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isPreamp)
            _buildSliderRow('Frequency', band['fc'], 20, 20000, isDark, (v) {
              setState(() { band['fc'] = v; _onBandChanged(); });
            }),
          _buildSliderRow('Gain', band['gain'], -20, 20, isDark, (v) {
            setState(() { band['gain'] = v; _onBandChanged(); });
          }, unit: 'dB'),
          if (!isPreamp)
            _buildSliderRow('Q Factor', band['q'], 0.1, 10, isDark, (v) {
              setState(() { band['q'] = v; _onBandChanged(); });
            }),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, bool isDark, ValueChanged<double> onChanged, {String unit = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: LuminaColors.labelSecondary)),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SizedBox(
            height: 32,
            child: CupertinoSlider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: LuminaColors.accent,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class EqVisualizerPainter extends CustomPainter {
  final List<Map<String, dynamic>> bands;
  final bool isDark;
  EqVisualizerPainter(this.bands, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    // Background Grid
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;
    
    for (final db in [-12.0, -6.0, 0.0, 6.0, 12.0]) {
      final y = _dbToY(db, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Reference line (0dB)
    canvas.drawLine(
      Offset(0, _dbToY(0, size)),
      Offset(size.width, _dbToY(0, size)),
      Paint()..color = LuminaColors.accent.withOpacity(0.15)..strokeWidth = 1.0
    );

    double preamp = 0.0;
    for (var b in bands) if (b['type'] == 'Preamp') preamp += b['gain'];

    final path = Path();
    final fillPath = Path();
    bool first = true;
    
    // High-fidelity curve sampling
    for (double x = 0; x <= size.width; x += 1) {
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

    // Elegant Gradient Fill
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        LuminaColors.accent.withOpacity(0.25),
        LuminaColors.accent.withOpacity(0.02),
      ],
    );
    canvas.drawPath(fillPath, Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    
    // Glow effect
    canvas.drawPath(
      path, 
      Paint()
        ..color = LuminaColors.accent.withOpacity(0.3)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
    );

    // Main Stroke
    canvas.drawPath(
      path, 
      Paint()
        ..color = LuminaColors.accent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
    );
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
    // Note: Other filters (LSC, HSC) should be implemented for full precision
    return 0;
  }

  double _dbToY(double db, Size size) => (size.height / 2) - (db / 24.0) * (size.height / 2);

  @override
  bool shouldRepaint(covariant EqVisualizerPainter old) => true; 
}
