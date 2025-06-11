import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';

class CharmBar extends ConsumerWidget {
  final String npcId;
  final String npcName;
  final double maxWidth;
  final double height;
  final double nameFontSize;
  final double charmFontSize;
  final Widget? trailing;

  const CharmBar({
    super.key,
    required this.npcId,
    required this.npcName,
    this.maxWidth = 320.0,
    this.height = 28.0,
    this.nameFontSize = 20.0,
    this.charmFontSize = 14.0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charmLevel = ref.watch(currentCharmLevelProvider(npcId));
    final double progress = (charmLevel / 100).clamp(0.0, 1.0);
    final barHeight = height;
    const borderRadius = BorderRadius.all(Radius.circular(14));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              npcName,
              style: TextStyle(
                fontSize: nameFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(blurRadius: 2.0, color: Colors.black, offset: Offset(1.5, 1.5)),
                  Shadow(blurRadius: 4.0, color: Colors.black54, offset: Offset(1.5, 1.5)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ]
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              width: maxWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF301934),
                borderRadius: borderRadius,
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: maxWidth * progress,
              height: barHeight,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF94C83), Color(0xFFC23D7F), Color(0xFF8F2D79)],
                  stops: [0.0, 0.5, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  'Charm: $charmLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    shadows: [
                      Shadow(
                        blurRadius: 1.0,
                        color: Colors.black,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
} 