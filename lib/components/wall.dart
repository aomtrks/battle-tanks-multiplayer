import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Wall extends PositionComponent {
  final Color color;
  late final Paint _paint;

  Wall({required Vector2 position, required Vector2 size, this.color = Colors.grey})
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
  }
}