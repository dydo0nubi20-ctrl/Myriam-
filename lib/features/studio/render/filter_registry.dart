library;

/// Color matrices shared by the live preview (`ColorFiltered` widget takes
/// exactly this 4x5 row-major format) and the export adapters, so the
/// filter you see while editing is bit-for-bit the same one applied on
/// export instead of two slightly different implementations drifting
/// apart over time.
class FilterDescriptor {
  final String id;
  final String label;
  final List<double> matrix;
  const FilterDescriptor({required this.id, required this.label, required this.matrix});
}

class FilterRegistry {
  FilterRegistry._();

  static const FilterDescriptor none = FilterDescriptor(
    id: 'none',
    label: 'Original',
    matrix: [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ],
  );

  static const FilterDescriptor sepia = FilterDescriptor(
    id: 'sepia',
    label: 'Sepia',
    matrix: [
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0, 0, 0, 1, 0,
    ],
  );

  static const FilterDescriptor blackAndWhite = FilterDescriptor(
    id: 'bw',
    label: 'B&W',
    matrix: [
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ],
  );

  static const FilterDescriptor vivid = FilterDescriptor(
    id: 'vivid',
    label: 'Vivid',
    matrix: [
      1.3, 0, 0, 0, -22,
      0, 1.3, 0, 0, -22,
      0, 0, 1.3, 0, -22,
      0, 0, 0, 1, 0,
    ],
  );

  static const List<FilterDescriptor> all = [none, sepia, blackAndWhite, vivid];

  static FilterDescriptor byId(String id) => all.firstWhere((f) => f.id == id, orElse: () => none);
}
