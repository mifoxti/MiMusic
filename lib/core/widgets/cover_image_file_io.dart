import 'dart:io';

import 'package:flutter/material.dart';

Widget buildCoverImageFromFile(
  String path,
  double width,
  double height,
  BorderRadius borderRadius,
  Widget placeholder,
  BoxFit fit,
) {
  final file = File(path);
  if (!file.existsSync()) return placeholder;
  return ClipRRect(
    borderRadius: borderRadius,
    child: SizedBox(
      width: width,
      height: height,
      child: Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, e, st) => placeholder,
      ),
    ),
  );
}
