import 'package:flutter/widgets.dart';

const floatingNavBarHeight = 68.0;
const floatingNavBarBottomMargin = 12.0;

/// Espacio inferior que ocupa el menú flotante, incluida el área segura.
double floatingNavBarClearance(BuildContext context) =>
    floatingNavBarHeight +
    floatingNavBarBottomMargin +
    MediaQuery.viewPaddingOf(context).bottom;
