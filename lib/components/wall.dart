import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Wall extends PositionComponent {
  final Color color;
  final bool isGoal; // YENİ: Bu duvar bir kale mi?
  final int teamId;  // YENİ: Kale hangi takıma ait?
  
  late final Paint _paint;

  Wall({required Vector2 position, required Vector2 size, this.color = Colors.grey, this.isGoal = false, this.teamId = -1})
      : super(position: position, size: size) {
    _paint = Paint()..color = color;
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _paint);
    
    // Kale ise ağ görüntüsü çizmek için çapraz çizgiler atılır
    if (isGoal) {
      final Paint netPaint = Paint()..color = Colors.white54..strokeWidth = 1;
      for (double i = 0; i < size.x; i += 10) canvas.drawLine(Offset(i, 0), Offset(i, size.y), netPaint);
      for (double i = 0; i < size.y; i += 10) canvas.drawLine(Offset(0, i), Offset(size.x, i), netPaint);
    }
  }
}