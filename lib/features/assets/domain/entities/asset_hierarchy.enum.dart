/// Jerarquía de niveles dentro de la estructura de activos
/// (Equipos -> Sub-equipos -> Partes -> Sub-partes).
enum AssetHierarchy { parent, child }

extension AssetHierarchyLabel on AssetHierarchy {
  String get label {
    switch (this) {
      case AssetHierarchy.parent:
        return 'Padre';
      case AssetHierarchy.child:
        return 'Hijo';
    }
  }
}
