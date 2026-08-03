import 'package:flutter/material.dart';

class PulseFireIcon extends StatefulWidget {
  final double size;
  const PulseFireIcon({super.key, this.size = 18});

  @override
  State<PulseFireIcon> createState() => _PulseFireIconState();
}

class _PulseFireIconState extends State<PulseFireIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Icon(Icons.local_fire_department, color: Colors.orange, size: widget.size),
    );
  }
}