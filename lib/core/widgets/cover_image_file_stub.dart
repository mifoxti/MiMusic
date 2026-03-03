import 'package:flutter/material.dart';

Widget buildCoverImageFromFile(
  String path,
  double width,
  double height,
  BorderRadius borderRadius,
  Widget placeholder,
  BoxFit fit,
) {
  return ClipRRect(
    borderRadius: borderRadius,
    child: SizedBox(width: width, height: height, child: placeholder),
  );
}
