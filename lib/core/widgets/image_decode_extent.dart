/// Infinite layout extents mean "fill parent", not a pixel decoding size.
/// Flutter resolves those through layout; never round infinity to an integer.
int? imageDecodeExtent(double extent) {
  if (!extent.isFinite || extent <= 0) return null;
  return (extent * 3).clamp(1, 2048).ceil();
}
