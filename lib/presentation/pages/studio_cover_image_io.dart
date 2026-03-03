import 'dart:io';

import 'package:flutter/material.dart';

Widget studioCoverImageFromFile(String path, double size, Widget placeholder) {
  final file = File(path);
  if (!file.existsSync()) return placeholder;
  return Image.file(
    file,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => placeholder,
  );
}
