import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Wall extends PositionComponent {
  Wall({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    // Çarpışma algılayıcıyı duvara ekliyoruz
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Duvarları basit bir gri renkle çizelim
    final paint = Paint()..color = Colors.grey.shade800;
    canvas.drawRect(size.toRect(), paint);
  }
}