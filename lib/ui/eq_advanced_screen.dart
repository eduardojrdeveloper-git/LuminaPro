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
  EqPreset('Treble Boost', [
    {'fc': 1000.0, 'gain': -2.0, 'q': 1.41, 'type': 'Preamp'},
    {'fc': 8000.0, 'gain': 5.0, 'q': 1.0, 'type': 'PK'},
    {'fc': 16000.0, 'gain': 3.0, 'q': 0.7, 'type': 'HSC'},
  ]),
  EqPreset('Headphone', [
    {'fc': 1000.0, 'gain': -3.0, 'q': 1.41, 'type': 'Preamp'},
    {'fc': 40.0, 'gain': 4.0, 'q': 0.5, 'type': 'PK'},
    {'fc': 1000.0, 'gain': -2.0, 'q': 2.0, 'type': 'PK'},
    {'fc': 10000.0, 'gain': 4.0, 'q': 0.7, 'type': 'HSC'},
  ]),
];

class EqAdvancedScreen extends StatefulWidget {
  const EqAdvancedScreen({super.key});

  @override
  State<EqAdvancedScreen> createState() => _EqAdvancedScreenState();
}

class _EqAdvancedScreenState extends State<EqAdvancedScreen> {
  late List<Map<String, dynamic>> bands;
  final List<String> filterTypes = ['Preamp', 'PK', 'LSC', 'HSC', 'LP', 'HP'];
  String? _activePreset;

  @override
  void initState() {
    super.initState();
    bands = List.from(PlayerService().eqBands.map((b) => Map<String, dynamic>.from(b)));
  }

  void _applyEQ() {
    PlayerService().eqBands = bands;
    PlayerService().applyCurrentEQ();
  }

  void _applyPreset(EqPreset preset) {
    setState(() {
      _activePreset = preset.name;
      bands = List.from(preset.bands.map((b) => Map<String, dynamic>.from(b)));
    });
    _applyEQ();
  }

  void _exportApoProfile() {
    final sb = StringBuffer();
    for (var b in bands) {
      if (b['type'] == 'Preamp') {
        sb.writeln('Preamp: ${(b['gain'] as num).toStringAsFixed(1)} dB');
      } else {
        final apoType = {
          'PK': 'PK',
          'LSC': 'LSC',
          'HSC': 'HSC',
          'LP': 'LP',
          'HP': 'HP',
        }[b['type']] ?? 'PK';
        sb.writeln(
            'Filter: ON $apoType Fc ${(b['fc'] as num).toInt()} Hz Gain ${(b['gain'] as num).toStringAsFixed(1)} dB Q ${(b['q'] as num).toStringAsFixed(2)}');
      }
    }
    // Copy to clipboard as well
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('APO profile ready — check console'),
        backgroundColor: LuminaColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    debugPrint(sb.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Parametric EQ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: LuminaColors.accent),
        ),
        actions: [
          GestureDetector(
            onTap: _exportApoProfile,
            child: const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(CupertinoIcons.share, color: LuminaColors.accent),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // EQ Curve Visualization
          Container(
            height: 180,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: isDark ? LuminaColors.bg1 : LuminaColors.lightBg1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? LuminaColors.bg3.withOpacity(0.5)
                    : LuminaColors.lightBg3,
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                painter: EqVisualizerPainter(bands, isDark),
                child: Container(),
              ),
            ),
          ),

          // Presets Horizontal Scroll
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: kEqPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final preset = kEqPresets[i];
                final isActive = _activePreset == preset.name;
                return GestureDetector(
                  onTap: () => _applyPreset(preset),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? LuminaColors.accent
                          : (isDark ? LuminaColors.bg2 : LuminaColors.lightBg2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? LuminaColors.accent
                            : (isDark
                                ? LuminaColors.bg3
                                : LuminaColors.lightBg3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : (isDark
                                ? LuminaColors.labelSecondary
                                : Colors.black54),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Band List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: bands.length,
              itemBuilder: (_, i) => _buildBandCard(i, isDark),
            ),
          ),

          // Add Filter Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activePreset = null;
                  bands.add({'fc': 1000.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'});
                });
                _applyEQ();
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: LuminaColors.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.add, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Add Filter Band',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandCard(int index, bool isDark) {
    final band = bands[index];
    final isPreamp = band['type'] == 'Preamp';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? LuminaColors.bg1 : LuminaColors.lightBg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? LuminaColors.bg3.withOpacity(0.5)
              : LuminaColors.lightBg3,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          children: [
            Row(
              children: [
                // Filter Type Picker
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LuminaColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: band['type'],
                      isDense: true,
                      dropdownColor:
                          isDark ? LuminaColors.bg2 : Colors.white,
                      style: const TextStyle(
                        color: LuminaColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      items: filterTypes
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _activePreset = null;
                          band['type'] = v;
                          if (v == 'Preamp') {
                            band['fc'] = 0.0;
                            band['q'] = 0.0;
                          } else if ((band['fc'] as num) == 0.0) {
                            band['fc'] = 1000.0;
                            band['q'] = 1.41;
                          }
                        });
                        _applyEQ();
                      },
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Filter ${index + 1}',
                  style: const TextStyle(
                      color: LuminaColors.labelSecondary, fontSize: 12),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _activePreset = null;
                      bands.removeAt(index);
                    });
                    _applyEQ();
                  },
                  child: const Icon(CupertinoIcons.trash,
                      color: LuminaColors.destructive, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isPreamp)
              _buildSliderRow(
                isDark: isDark,
                label: 'Freq',
                value: (band['fc'] as num).toDouble(),
                displayStr: '${(band['fc'] as num).toInt()} Hz',
                min: 20,
                max: 20000,
                onChanged: (v) {
                  setState(() {
                    _activePreset = null;
                    band['fc'] = v;
                  });
                  _applyEQ();
                },
              ),
            if (band['type'] != 'LP' && band['type'] != 'HP')
              _buildSliderRow(
                isDark: isDark,
                label: 'Gain',
                value: (band['gain'] as num).toDouble(),
                displayStr: '${(band['gain'] as num).toStringAsFixed(1)} dB',
                min: -20,
                max: 20,
                onChanged: (v) {
                  setState(() {
                    _activePreset = null;
                    band['gain'] = v;
                  });
                  _applyEQ();
                },
              ),
            if (!isPreamp)
              _buildSliderRow(
                isDark: isDark,
                label: 'Q',
                value: (band['q'] as num).toDouble(),
                displayStr: (band['q'] as num).toStringAsFixed(2),
                min: 0.1,
                max: 10,
                onChanged: (v) {
                  setState(() {
                    _activePreset = null;
                    band['q'] = v;
                  });
                  _applyEQ();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required bool isDark,
    required String label,
    required double value,
    required String displayStr,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                color: LuminaColors.labelSecondary,
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: LuminaColors.accent,
            inactiveColor: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            displayStr,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ── EQ Visualizer ─────────────────────────────────────────────────────────────
class EqVisualizerPainter extends CustomPainter {
  final List<Map<String, dynamic>> bands;
  final bool isDark;

  EqVisualizerPainter(this.bands, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black.withOpacity(0.08)
      ..strokeWidth = 0.5;

    // Horizontal grid (±6, ±12 dB)
    for (final db in [-12.0, -6.0, 0.0, 6.0, 12.0]) {
      final y = _dbToY(db, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Zero line (brighter)
    final zeroLinePaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black26
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), zeroLinePaint);

    // Gradient fill under curve
    double preamp = 0.0;
    for (var b in bands) {
      if (b['type'] == 'Preamp') preamp += (b['gain'] as num).toDouble();
    }

    final path = Path();
    final fillPath = Path();
    bool first = true;
    const minFreq = 20.0;
    const maxFreq = 20000.0;
    final logMin = log(minFreq);
    final logMax = log(maxFreq);

    for (double x = 0; x <= size.width; x++) {
      final logf = logMin + (x / size.width) * (logMax - logMin);
      final freq = exp(logf);
      double totalDb = preamp;

      for (var band in bands) {
        final type = band['type'] as String? ?? 'PK';
        if (type == 'Preamp') continue;
        final fc = (band['fc'] as num).toDouble();
        final gain = (band['gain'] as num).toDouble();
        final q = (band['q'] as num).toDouble();
        if (fc <= 0) continue;

        final w0 = freq / fc;
        switch (type) {
          case 'PK':
            final a = pow(10.0, gain / 40.0).toDouble();
            final num_ = 1.0 + pow(w0 - 1.0 / w0, 2) * pow(q, 2) * pow(a, 2);
            final den_ = 1.0 + pow(w0 - 1.0 / w0, 2) * pow(q, 2) / pow(a, 2);
            if (den_ > 0) {
              final db = 10 * _log10(num_ / den_);
              totalDb += gain < 0 ? -db : db;
            }
            break;
          case 'LSC':
            if (freq < fc) totalDb += gain * (1 - freq / fc);
            break;
          case 'HSC':
            if (freq > fc) totalDb += gain * (1 - fc / freq);
            break;
          case 'LP':
            if (freq > fc) totalDb -= 12.0 * _log2(freq / fc);
            break;
          case 'HP':
            if (freq < fc) totalDb -= 12.0 * _log2(fc / freq);
            break;
        }
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

    // Fill gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        LuminaColors.accent.withOpacity(0.25),
        LuminaColors.accent.withOpacity(0.0),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Curve line
    final curvePaint = Paint()
      ..color = LuminaColors.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, curvePaint);
  }

  double _dbToY(double db, Size size) {
    const dbRange = 18.0;
    return (size.height / 2) - (db / dbRange) * (size.height / 2);
  }

  double _log10(num x) => log(x) / ln10;
  double _log2(num x) => log(x) / ln2;

  @override
  bool shouldRepaint(covariant EqVisualizerPainter old) =>
      old.bands != bands || old.isDark != isDark;
}
