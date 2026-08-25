class Validators {
  const Validators._();

  static final RegExp _assetIdPattern = RegExp(r'^[A-Z]\d{1,3}-\d{3,4}$');

  static bool isValidAssetId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return _assetIdPattern.hasMatch(id.trim().toUpperCase());
  }

  static String? validateRequired(String? value, {String fieldName = 'El campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es obligatorio.';
    }
    return null;
  }
}
