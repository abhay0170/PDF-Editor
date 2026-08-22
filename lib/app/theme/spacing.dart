/// 8-point spacing scale. Do not use arbitrary spacing values outside this set.
class Spacing {
  const Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;
  static const double giant = 64;

  /// Standard screen horizontal padding.
  static const double screenHorizontal = xl;
  static const double sectionSpacing = xxxl;
  static const double toolbarHeight = 48;
  static const double listRowHeight = 60;

  /// Bottom clearance for scrollable content on a screen with a
  /// [FloatingActionButton], so the FAB doesn't rest permanently over the
  /// last item once scrolling stops. A standard FAB is ~56 tall plus a
  /// ~16 margin from the screen edge (~72 total); this adds real breathing
  /// room on top of that footprint.
  static const double fabClearance = 96;
}
