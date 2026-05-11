import 'dart:ui';
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
    {'fc': 1000.0, 'gain': -1.0, 'q': 1.41, 'type': 'Preamp'},
    {'fc': 8000.0, 'gain': 5.0, 'q': 1.0, 'type': 'PK'},
    {'fc': 16000.0, 'gain': 3.0, 'q': 0.8, 'type': 'PK'},
  ]),
  EqPreset('Loudness', [
    {'fc': 1000.0, 'gain': -3.0, 'q': 1.41, 'type': 'Preamp'},
    {'fc': 60.0, 'gain': 5.0, 'q': 0.7, 'type': 'PK'},
    {'fc': 12000.0, 'gain': 4.0, 'q': 0.9, 'type': 'PK'},
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
  int _selectedPresetIndex = 0;
  final GlobalKey<AnimatedListState> _listKey =
      GlobalKey<AnimatedListState>();

  // ValueNotifier for real-time visualizer repaints
  late final ValueNotifier<List<Map<String, dynamic>>> _bandsNotifier;

  @override
  void initState() {
    super.initState();
    _bands =
        List.from(_ps.eqBands.map((b) => Map<String, dynamic>.from(b)));
    _bandsNotifier = ValueNotifier(_bands);
  }

  void _onBandChanged() {
    _bandsNotifier.value = List.from(_bands);
    _ps.eqBands = _bands;
    _ps.applyCurrentEQ();
  }

  void _applyPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      final preset = kEqPresets[index];
      // Clear existing list
      for (int i = _bands.length - 1; i >= 0; i--) {
        final removed = _bands[i];
        _listKey.currentState?.removeItem(
          i,
          (context, anim) => _buildAnimatedBandRow(
              removed, anim, i, Theme.of(context).brightness == Brightness.dark),
        );
      }
      _bands.clear();
      // Add preset bands
      for (int i = 0; i < preset.bands.length; i++) {
        _bands.add(Map<String, dynamic>.from(preset.bands[i]));
        _listKey.currentState?.insertItem(i);
      }
      _onBandChanged();
    });
  }

  void _resetEq() {
    _applyPreset(0); // Reset to Flat
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _listKey.currentState?.removeItem(
      index,
      (context, animation) =>
          _buildAnimatedBandRow(removed, animation, index, isDark),
    );
    setState(() {
      _bands.removeAt(index);
      _onBandChanged();
    });
  }

  Future<void> _showEditPopup(int index, String field, double initialValue, {double min = 0, double max = 20000}) async {
    final TextEditingController ctrl = TextEditingController(text: initialValue.toStringAsFixed(1));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Edit $field'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            placeholder: 'Value ($min - $max)',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                setState(() {
                  _bands[index][field == 'Frequency' ? 'fc' : (field == 'Gain' ? 'gain' : 'q')] = val.clamp(min, max);
                  _onBandChanged();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Parametric EQ',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: -0.3,
            decoration: TextDecoration.none,
          ),
        ),
        backgroundColor:
            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.88),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.chevron_back,
              color: LuminaColors.accent),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.only(right: 8),
              onPressed: _resetEq,
              child: const Text(
                'Reset',
                style: TextStyle(
                    color: LuminaColors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _addBand,
              child: const Icon(CupertinoIcons.add_circled,
                  color: LuminaColors.accent, size: 22),
            ),
          ],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Column(
            children: [
              // ── Real-time EQ Visualizer ──────────────────────────────────
              Container(
                height: 160,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _bandsNotifier,
                    builder: (_, bands, __) => CustomPaint(
                      painter: EqVisualizerPainter(bands, isDark),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),

              // ── Presets — Horizontal Scroll Chips ────────────────────────
              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: kEqPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final isSelected = _selectedPresetIndex == i;
                    return GestureDetector(
                      onTap: () => _applyPreset(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? LuminaColors.accent
                              : (isDark ? LuminaColors.bg2 : LuminaColors.lightBg2),
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.08),
                                  width: 0.5,
                                ),
                        ),
                        child: Text(
                          kEqPresets[i].name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? Colors.white
                                    : Colors.black87),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ── Bands List ───────────────────────────────────────────────
              Expanded(
                child: AnimatedList(
                  key: _listKey,
                  initialItemCount: _bands.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index, animation) {
                    return _buildAnimatedBandRow(
                        _bands[index], animation, index, isDark);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBandRow(Map<String, dynamic> band,
      Animation<double> animation, int index, bool isDark) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        child: _buildBandCard(band, index, isDark),
      ),
    );
  }

  Widget _buildBandCard(
      Map<String, dynamic> band, int index, bool isDark) {
    final isPreamp = band['type'] == 'Preamp';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LuminaColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  band['type'].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: LuminaColors.accent,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const Spacer(),
              if (!isPreamp)
                GestureDetector(
                  onTap: () => _showEditPopup(index, 'Frequency', band['fc'], min: 20, max: 20000),
                  child: Text(
                    '${band['fc'].toInt()} Hz',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LuminaColors.accent,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _removeBand(index),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(CupertinoIcons.minus_circle_fill,
                      size: 20, color: LuminaColors.destructive),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!isPreamp)
            _buildSliderRow(index, 'Frequency', band['fc'], 20, 20000, isDark,
                (v) {
              setState(() {
                band['fc'] = v;
                _onBandChanged();
              });
            }),
          _buildSliderRow(index, 'Gain', band['gain'], -20, 20, isDark, (v) {
            setState(() {
              band['gain'] = v;
              _onBandChanged();
            });
          }, unit: 'dB'),
          if (!isPreamp)
            _buildSliderRow(index, 'Q Factor', band['q'], 0.1, 10, isDark, (v) {
              setState(() {
                band['q'] = v;
                _onBandChanged();
              });
            }),
        ],
      ),
    );
  }

  Widget _buildSliderRow(int index, String label, double value, double min, double max,
      bool isDark, ValueChanged<double> onChanged,
      {String unit = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: LuminaColors.labelSecondary,
                      decoration: TextDecoration.none)),
              GestureDetector(
                onTap: () => _showEditPopup(index, label, value, min: min, max: max),
                child: Text(
                  '${value.toStringAsFixed(1)} $unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LuminaColors.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 30,
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

// ── EQ Visualizer ─────────────────────────────────────────────────────────────
class EqVisualizerPainter extends CustomPainter {
  final List<Map<String, dynamic>> bands;
  final bool isDark;
  EqVisualizerPainter(this.bands, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid lines
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.05)
      ..strokeWidth = 0.5;

    for (final db in [-12.0, -6.0, 0.0, 6.0, 12.0]) {
      final y = _dbToY(db, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 0dB reference line — subtle accent
    canvas.drawLine(
      Offset(0, _dbToY(0, size)),
      Offset(size.width, _dbToY(0, size)),
      Paint()
        ..color = LuminaColors.accent.withOpacity(0.1)
        ..strokeWidth = 1.0,
    );

    // Frequency labels
    const freqLabels = [
      (20.0, '20'),
      (100.0, '100'),
      (1000.0, '1k'),
      (10000.0, '10k'),
      (20000.0, '20k'),
    ];
    final labelStyle = TextStyle(
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.25),
      fontSize: 9,
      decoration: TextDecoration.none,
    );
    for (final (freq, label) in freqLabels) {
      final x = _freqToX(freq, size.width);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 14));
    }

    double preamp = 0.0;
    for (var b in bands) {
      if (b['type'] == 'Preamp') preamp += (b['gain'] as double);
    }

    final path = Path();
    final fillPath = Path();
    bool first = true;

    for (double x = 0; x <= size.width; x += 1) {
      final freq =
          exp(log(20.0) + (x / size.width) * (log(20000.0) - log(20.0)));
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

    // Gradient fill — neutral white/gray tone for technical graph
    final gradientColor =
        isDark ? Colors.white : Colors.black;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        gradientColor.withOpacity(0.18),
        gradientColor.withOpacity(0.01),
      ],
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader =
            gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..color = LuminaColors.accent.withOpacity(0.25)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Main stroke — Apple Music uses a bright accent for the EQ curve
    canvas.drawPath(
      path,
      Paint()
        ..color = LuminaColors.accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  double _freqToX(double freq, double width) {
    return (log(freq) - log(20.0)) / (log(20000.0) - log(20.0)) * width;
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
      final n = 1.0 + pow(w0 - 1.0 / w0, 2) * pow(q, 2) * pow(a, 2);
      final d = 1.0 + pow(w0 - 1.0 / w0, 2) * pow(q, 2) / pow(a, 2);
      return 10 * log(n / d) / ln10;
    }
    return 0;
  }

  double _dbToY(double db, Size size) =>
      (size.height / 2) - (db / 24.0) * (size.height / 2);

  @override
  bool shouldRepaint(covariant EqVisualizerPainter old) => true;
}
