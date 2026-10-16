import 'package:flutter/material.dart';

/// Original photographs from the supplied Figma occasion collage.
/// Keeps the public widget name and tile sizing used by the app and gallery.
class OccasionArtwork extends StatelessWidget {
  const OccasionArtwork({
    super.key,
    required this.seed,
    this.width,
    this.height,
  });

  final int seed;
  final double? width;
  final double? height;

  static const _photographs = [
    'assets/images/occasions/start-01.png',
    'assets/images/occasions/start-02.png',
    'assets/images/occasions/start-03.png',
    'assets/images/occasions/start-04.png',
    'assets/images/occasions/start-05.png',
    'assets/images/occasions/start-06.png',
    'assets/images/occasions/start-07.png',
    'assets/images/occasions/start-08.png',
    'assets/images/occasions/start-09.png',
    'assets/images/occasions/start-10.png',
  ];

  @override
  Widget build(BuildContext context) {
    final index = (seed - 1).abs() % _photographs.length;
    return Image.asset(
      _photographs[index],
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: index == 5 ? Alignment.topCenter : Alignment.center,
      excludeFromSemantics: true,
    );
  }
}
