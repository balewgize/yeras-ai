// Generates the Play Store and launcher brand assets from vector drawing code.
//
// Run from the repo root:
//   flutter test tool/branding/generate_brand_assets_test.dart --update-goldens
//
// Then regenerate launcher icons:
//   dart run flutter_launcher_icons

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Color kAccent = Color(0xFF2563EB);
const Color kDark = Color(0xFF101011);
const Color kMuted = Color(0xFFA1A1AA);
const Color kWhite = Color(0xFFFFFFFF);

const Size kSquare = Size(1024, 1024);

/// Draws the YerasAI monogram: three round-capped strokes forming a Y.
class YMonogram extends StatelessWidget {
  const YMonogram({super.key, required this.color, this.extent = 1});

  final Color color;

  /// Fraction of the canvas the mark should span.
  final double extent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _YMarkPainter(color: color, extent: extent),
      size: Size.infinite,
    );
  }
}

class _YMarkPainter extends CustomPainter {
  _YMarkPainter({required this.color, required this.extent});

  final Color color;
  final double extent;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final mark = side * extent;
    final cx = size.width / 2;
    final top = (size.height - mark) / 2;
    final strokeWidth = mark * 0.19;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Keep the visual mass balanced: the stem ends slightly above the
    // geometric bottom so the round cap does not look too low.
    final left = Offset(cx - mark * 0.30, top + mark * 0.10);
    final right = Offset(cx + mark * 0.30, top + mark * 0.10);
    final joint = Offset(cx, top + mark * 0.445);
    final bottom = Offset(cx, top + mark * 0.855);

    canvas.drawLine(left, joint, paint);
    canvas.drawLine(right, joint, paint);
    canvas.drawLine(joint, bottom, paint);
  }

  @override
  bool shouldRepaint(_YMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.extent != extent;
}

Widget _iconArt({required bool withBackground, double markExtent = 0.50}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: withBackground ? kAccent : Colors.transparent,
      borderRadius:
          withBackground ? BorderRadius.circular(kSquare.width * 0.22) : null,
    ),
    child: Center(
      child: SizedBox.expand(
        child: YMonogram(color: kWhite, extent: markExtent),
      ),
    ),
  );
}

Widget _playIcon() => _iconArt(withBackground: true, markExtent: 0.50);

Widget _adaptiveForeground() => _iconArt(withBackground: false, markExtent: 0.68);

Widget _featureGraphic() {
  return ColoredBox(
    color: kDark,
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(64, 52, 36, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'YERASAI',
                      style: TextStyle(
                        fontFamily: 'LatoDisplay',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: kWhite,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: kAccent, width: 1.5),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'ON-DEVICE',
                        style: TextStyle(
                          fontFamily: 'LatoDisplay',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: kAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Private AI.\nOffline. Free.',
                  style: TextStyle(
                    fontFamily: 'LatoDisplay',
                    fontSize: 64,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    color: kWhite,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Chat with open models running entirely on your phone.\nNo account. No cloud. No tracking.',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 21,
                    height: 1.45,
                    color: kMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 360,
          height: double.infinity,
          color: kAccent,
          child: const Center(
            child: YMonogram(color: kWhite, extent: 0.44),
          ),
        ),
      ],
    ),
  );
}

Future<void> _loadFont(String family, List<String> candidates) async {
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(
        Future<ByteData>.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
      );
    await loader.load();
    return;
  }
  // Text is still rendered with the test fallback if no font is installed;
  // brand assets should be generated on a machine with Lato or DejaVu.
}

Future<void> _capture(
  WidgetTester tester,
  Widget art,
  Size size,
  String outputPath,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: const ValueKey('art'),
        child: SizedBox.fromSize(size: size, child: art),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byKey(const ValueKey('art')),
    matchesGoldenFile(Uri.file(outputPath)),
  );
}

void main() {
  final root = Directory.current.path;

  setUpAll(() async {
    await _loadFont('Lato', [
      '/usr/share/fonts/truetype/lato/Lato-Regular.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ]);
    // FontLoader replaces the family, so load the bold face as a second
    // family used explicitly by display text.
    await _loadFont('LatoDisplay', [
      '/usr/share/fonts/truetype/lato/Lato-Bold.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    ]);
  });

  testWidgets('app icon 1024', (tester) async {
    await _capture(
      tester,
      _iconArt(withBackground: true, markExtent: 0.50),
      kSquare,
      '$root/assets/branding/app_icon.png',
    );
  });

  testWidgets('adaptive foreground 1024', (tester) async {
    await _capture(
      tester,
      _adaptiveForeground(),
      kSquare,
      '$root/assets/branding/app_icon_foreground.png',
    );
  });

  testWidgets('monochrome 1024', (tester) async {
    await _capture(
      tester,
      _adaptiveForeground(),
      kSquare,
      '$root/assets/branding/app_icon_monochrome.png',
    );
  });

  testWidgets('play icon 512', (tester) async {
    await _capture(
      tester,
      _playIcon(),
      const Size(512, 512),
      '$root/assets/branding/play_icon_512.png',
    );
  });

  testWidgets('feature graphic 1024x500', (tester) async {
    await _capture(
      tester,
      _featureGraphic(),
      const Size(1024, 500),
      '$root/assets/branding/feature_graphic.png',
    );
  });
}
