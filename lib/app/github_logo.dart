import 'package:flutter/material.dart';

class GitHubLogo extends StatelessWidget {
  const GitHubLogo({super.key, this.width = 44, this.height = 44, this.color});

  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor = color ?? (isDark ? Colors.white : const Color(0xFF181717));
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _GitHubLogoPainter(resolvedColor),
      ),
    );
  }
}

class _GitHubLogoPainter extends CustomPainter {
  const _GitHubLogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final scaleX = size.width / 16.0;
    final scaleY = size.height / 16.0;
    final path = Path()
      ..moveTo(8 * scaleX, 0 * scaleY)
      ..cubicTo(3.58 * scaleX, 0 * scaleY, 0 * scaleX, 3.58 * scaleY, 0 * scaleX, 8 * scaleY)
      ..cubicTo(0 * scaleX, 11.54 * scaleY, 2.29 * scaleX, 14.53 * scaleY, 5.47 * scaleX, 15.59 * scaleY)
      ..cubicTo(5.87 * scaleX, 15.66 * scaleY, 6.02 * scaleX, 15.42 * scaleY, 6.02 * scaleX, 15.21 * scaleY)
      ..cubicTo(6.02 * scaleX, 15.02 * scaleY, 6.01 * scaleX, 14.39 * scaleY, 6.01 * scaleX, 13.72 * scaleY)
      ..cubicTo(3.99 * scaleX, 14.09 * scaleY, 3.47 * scaleX, 13.23 * scaleY, 3.31 * scaleX, 12.78 * scaleY)
      ..cubicTo(3.22 * scaleX, 12.55 * scaleY, 2.83 * scaleX, 11.84 * scaleY, 2.49 * scaleX, 11.65 * scaleY)
      ..cubicTo(2.21 * scaleX, 11.5 * scaleY, 1.81 * scaleX, 11.13 * scaleY, 2.48 * scaleX, 11.12 * scaleY)
      ..cubicTo(3.11 * scaleX, 11.11 * scaleY, 3.56 * scaleX, 11.7 * scaleY, 3.71 * scaleX, 11.94 * scaleY)
      ..cubicTo(4.43 * scaleX, 13.15 * scaleY, 5.58 * scaleX, 12.81 * scaleY, 6.04 * scaleX, 12.6 * scaleY)
      ..cubicTo(6.11 * scaleX, 12.08 * scaleY, 6.32 * scaleX, 11.73 * scaleY, 6.55 * scaleX, 11.53 * scaleY)
      ..cubicTo(4.77 * scaleX, 11.33 * scaleY, 2.91 * scaleX, 10.64 * scaleY, 2.91 * scaleX, 7.58 * scaleY)
      ..cubicTo(2.91 * scaleX, 6.71 * scaleY, 3.22 * scaleX, 5.99 * scaleY, 3.73 * scaleX, 5.43 * scaleY)
      ..cubicTo(3.65 * scaleX, 5.23 * scaleY, 3.37 * scaleX, 4.41 * scaleY, 3.81 * scaleX, 3.31 * scaleY)
      ..cubicTo(3.81 * scaleX, 3.31 * scaleY, 4.48 * scaleX, 3.1 * scaleY, 6.01 * scaleX, 4.13 * scaleY)
      ..cubicTo(6.65 * scaleX, 3.95 * scaleY, 7.33 * scaleX, 3.86 * scaleY, 8.01 * scaleX, 3.86 * scaleY)
      ..cubicTo(8.69 * scaleX, 3.86 * scaleY, 9.37 * scaleX, 3.95 * scaleY, 10.01 * scaleX, 4.13 * scaleY)
      ..cubicTo(11.54 * scaleX, 3.09 * scaleY, 12.21 * scaleX, 3.31 * scaleY, 12.21 * scaleX, 3.31 * scaleY)
      ..cubicTo(12.65 * scaleX, 4.41 * scaleY, 12.37 * scaleX, 5.23 * scaleY, 12.29 * scaleX, 5.43 * scaleY)
      ..cubicTo(12.8 * scaleX, 5.99 * scaleY, 13.11 * scaleX, 6.7 * scaleY, 13.11 * scaleX, 7.58 * scaleY)
      ..cubicTo(13.11 * scaleX, 10.65 * scaleY, 11.24 * scaleX, 11.33 * scaleY, 9.46 * scaleX, 11.53 * scaleY)
      ..cubicTo(9.75 * scaleX, 11.78 * scaleY, 10.0 * scaleX, 12.26 * scaleY, 10.0 * scaleX, 13.01 * scaleY)
      ..cubicTo(10.0 * scaleX, 14.08 * scaleY, 9.99 * scaleX, 14.94 * scaleY, 9.99 * scaleX, 15.21 * scaleY)
      ..cubicTo(9.99 * scaleX, 15.42 * scaleY, 10.14 * scaleX, 15.67 * scaleY, 10.54 * scaleX, 15.59 * scaleY)
      ..cubicTo(13.71 * scaleX, 14.53 * scaleY, 16.0 * scaleX, 11.54 * scaleY, 16.0 * scaleX, 8.0 * scaleY)
      ..cubicTo(16.0 * scaleX, 3.58 * scaleY, 12.42 * scaleX, 0 * scaleY, 8.0 * scaleX, 0 * scaleY)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GitHubLogoPainter oldDelegate) => oldDelegate.color != color;
}
