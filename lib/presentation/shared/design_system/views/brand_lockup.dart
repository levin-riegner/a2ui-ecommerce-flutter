import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    heightFactor: 1,
    child: Semantics(
      label: 'ALDER',
      image: true,
      child: SvgPicture.asset(
        'assets/images/occasions/alder-wordmark.svg',
        excludeFromSemantics: true,
      ),
    ),
  );
}
