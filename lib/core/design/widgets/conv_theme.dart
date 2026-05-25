import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Convenience getter for the [ConvocationColors] theme extension.
extension ConvocationContext on BuildContext {
  ConvocationColors get conv =>
      Theme.of(this).extension<ConvocationColors>() ?? ConvocationColors.light;
}
