/// Entidad de dominio que representa la información de versión disponible para Android.
class AppVersionInfo {
  const AppVersionInfo({
    required this.id,
    required this.version,
    this.downloadUrl,
    required this.mandatory,
    this.releaseDate,
  });

  final int id;
  final String version;
  final String? downloadUrl;
  final bool mandatory;
  final String? releaseDate;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      id: json['id'] as int? ?? 0,
      version: json['version'] as String? ?? '1.0.0',
      downloadUrl: json['downloadUrl'] as String?,
      mandatory: json['mandatory'] as bool? ?? false,
      releaseDate: json['releaseDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'downloadUrl': downloadUrl,
      'mandatory': mandatory,
      'releaseDate': releaseDate,
    };
  }
}

