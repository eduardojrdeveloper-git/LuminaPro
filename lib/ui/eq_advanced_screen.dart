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
  EqPreset('IA500', PlayerService().parseApoContent(PlayerService.ia500Config)),
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
    _selectedPresetIndex = index;
    final preset = kEqPresets[index];

    // 1. Capture snapshot BEFORE mutating _bands
    final oldBands = List<Map<String, dynamic>>.from(_bands);

    // 2. Animate removals using the snapshot
    for (int i = oldBands.length - 1; i >= 0; i--) {
      final removed = oldBands[i];
      _listKey.currentState?.removeItem(
        i,
        (ctx, anim) => _buildAnimatedBandRow(
            removed, anim, i, Theme.of(context).brightness == Brightness.dark),
        duration: const Duration(milliseconds: 200),
      );
    }

    // 3. Mutate state
    setState(() {
      _bands.clear();
      for (int i = 0; i < preset.bands.length; i++) {
        _bands.add(Map<String, dynamic>.from(preset.bands[i]));
      }
      _onBandChanged();
    });

    // 4. Insert animations AFTER the removals animate out
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      for (int i = 0; i < _bands.length; i++) {
        _listKey.currentState?.insertItem(i,
            duration: const Duration(milliseconds: 180));
      }
    });
  }

  void _resetEq() {
    _applyPreset(0); // Reset to Flat
  }

  void _addBand() {
    final newBand = {'fc': 1000.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'};
    setState(() => _bands.add(newBand));
    _listKey.currentState?.insertItem(_bands.length - 1);
    _onBandChanged();
  }

  void _removeBand(int index) {
    if (index < 0 || index >= _bands.length) return;
    final removed = Map<String, dynamic>.from(_bands[index]);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _listKey.currentState?.removeItem(
      index,
      (context, animation) =>
          _buildAnimatedBandRow(removed, animation, index, isDark),
      duration: const Duration(milliseconds: 200),
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
              if (val != null && mounted) {
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
        middle: const Text(
          'Parametric EQ',
          style: TextStyle(
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
      if (b['type'] == 'Preamp') preamp += (b['gain'] as num).toDouble();
    }

    // ── Draw Preamp line (separate) ────────────────────────────────
    final preampY = _dbToY(preamp, size);
    final preampPaint = Paint()
      ..color = LuminaColors.accent.withOpacity(0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Draw dashed preamp line
    double dashWidth = 5, dashSpace = 5, startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, preampY), Offset(startX + dashWidth, preampY), preampPaint);
      startX += dashWidth + dashSpace;
    }

    final path = Path();
    final fillPath = Path();
    bool first = true;

    for (double x = 0; x <= size.width; x += 1) {
      final freq =
          exp(log(20.0) + (x / size.width) * (log(20000.0) - log(20.0)));
      double totalDb = 0.0; // Start at 0, don't include preamp in curve
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
    final fc   = (band['fc']   as num).toDouble();
    final gain = (band['gain'] as num).toDouble();
    final q    = (band['q']    as num).toDouble();
    if (fc <= 0) return 0;
    
    // Preamp is global, shouldn't be here but handled for safety
    if (type == 'Preamp') return 0;

    // Using Audio EQ Cookbook based magnitude calculation
    // This is an approximation of the digital filter response
    final double fs = 44100.0; // Assume 44.1kHz for visualization
    final double w0 = 2 * pi * fc / fs;
    final double w = 2 * pi * freq / fs;
    final double alpha = sin(w0) / (2 * q);
    final double A = pow(10, gain / 40.0).toDouble();

    double b0, b1, b2, a0, a1, a2;

    switch (type) {
      case 'PK':
        b0 = 1 + alpha * A;
        b1 = -2 * cos(w0);
        b2 = 1 - alpha * A;
        a0 = 1 + alpha / A;
        a1 = -2 * cos(w0);
        a2 = 1 - alpha / A;
        break;
      case 'LS':
      case 'LSC':
        b0 = A * ((A + 1) - (A - 1) * cos(w0) + 2 * sqrt(A) * alpha);
        b1 = 2 * A * ((A - 1) - (A + 1) * cos(w0));
        b2 = A * ((A + 1) - (A - 1) * cos(w0) - 2 * sqrt(A) * alpha);
        a0 = (A + 1) + (A - 1) * cos(w0) + 2 * sqrt(A) * alpha;
        a1 = -2 * ((A - 1) + (A + 1) * cos(w0));
        a2 = (A + 1) + (A - 1) * cos(w0) - 2 * sqrt(A) * alpha;
        break;
      case 'HS':
      case 'HSC':
        b0 = A * ((A + 1) + (A - 1) * cos(w0) + 2 * sqrt(A) * alpha);
        b1 = -2 * A * ((A - 1) + (A + 1) * cos(w0));
        b2 = A * ((A + 1) + (A - 1) * cos(w0) - 2 * sqrt(A) * alpha);
        a0 = (A + 1) - (A - 1) * cos(w0) + 2 * sqrt(A) * alpha;
        a1 = 2 * ((A - 1) - (A + 1) * cos(w0));
        a2 = (A + 1) - (A - 1) * cos(w0) - 2 * sqrt(A) * alpha;
        break;
      default:
        return 0;
    }

    // Magnitude response of biquad
    // H(z) = (b0 + b1*z^-1 + b2*z^-2) / (a0 + a1*z^-1 + a2*z^-2)
    final double n = b0*b0 + b1*b1 + b2*b2 + 2*(b0*b1 + b1*b2)*cos(w) + 2*b0*b2*cos(2*w);
    final double d = a0*a0 + a1*a1 + a2*a2 + 2*(a0*a1 + a1*a2)*cos(w) + 2*a0*a2*cos(2*w);
    
    return 10 * log(max(n / d, 1e-10)) / ln10;
  }

  double _dbToY(double db, Size size) =>
      (size.height / 2) - (db / 24.0) * (size.height / 2);

  @override
  bool shouldRepaint(covariant EqVisualizerPainter old) => true;
}
