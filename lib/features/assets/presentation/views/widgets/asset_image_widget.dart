import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../../app/di/get_it.dart';
import '../../../../../core/network/api_client.dart';

/// Widget para renderizar imágenes de activos de forma eficiente.
/// Soporta URLs relativas del servidor (/image/...), URLs absolutas (http...)
/// y fallback retrocompatible para strings Base64.
class AssetImageWidget extends StatelessWidget {
  const AssetImageWidget({
    super.key,
    required this.imageData,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.precision_manufacturing_outlined,
    this.fallbackColor,
    this.fallbackBgColor,
  });

  final String? imageData;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final Color? fallbackBgColor;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(8);
    final data = imageData?.trim();

    if (data == null || data.isEmpty) {
      return _buildFallback(context, br);
    }

    // 1. Caso URL de Servidor (relativa o absoluta)
    if (data.startsWith('/image') ||
        data.startsWith('image/') ||
        data.startsWith('http://') ||
        data.startsWith('https://')) {
      final apiClient = getIt<ApiClient>();
      final fullUrl = apiClient.resolveImageUrl(data);

      return ClipRRect(
        borderRadius: br,
        child: SizedBox(
          width: width,
          height: height,
          child: Image.network(
            fullUrl,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: width,
                height: height,
                color: fallbackBgColor ?? Colors.grey.shade100,
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => _buildFallback(context, br, isError: true),
          ),
        ),
      );
    }

    // 2. Caso Base64 (retrocompatibilidad)
    try {
      final base64String = data.contains(',') ? data.split(',').last : data;
      final bytes = base64Decode(base64String);
      return ClipRRect(
        borderRadius: br,
        child: SizedBox(
          width: width,
          height: height,
          child: Image.memory(
            bytes,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(context, br, isError: true),
          ),
        ),
      );
    } catch (_) {
      return _buildFallback(context, br, isError: true);
    }
  }

  Widget _buildFallback(BuildContext context, BorderRadius br, {bool isError = false}) {
    final color = fallbackColor ?? const Color(0xFF1E3A8A);
    final bgColor = fallbackBgColor ?? color.withValues(alpha: 0.1);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: br,
      ),
      alignment: Alignment.center,
      child: Icon(
        isError ? Icons.broken_image_outlined : fallbackIcon,
        size: (width != null && height != null) ? (width! * 0.45).clamp(14, 32) : 20,
        color: isError ? Colors.grey.shade500 : color,
      ),
    );
  }
}
