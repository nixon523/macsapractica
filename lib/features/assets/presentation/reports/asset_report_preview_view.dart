import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/utils/universal_file_saver.dart';

/// Modelo de tamaño de papel soportado
enum PaperSizeOption {
  letter('Carta (Letter)', PdfPageFormat.letter),
  legal('Oficio (Legal)', PdfPageFormat.legal),
  a4('A4 (Estándar)', PdfPageFormat.a4);

  const PaperSizeOption(this.label, this.format);
  final String label;
  final PdfPageFormat format;
}

/// Vista de previsualización formal interactiva para reportes PDF
/// Permite configuración en tiempo real de:
/// - Tamaño de Papel (Carta, Oficio / Legal, A4)
/// - Orientación (Vertical / Retrato [por defecto], Horizontal / Paisaje)
/// - Niveles de Zoom interactivos
/// - Impresión directa con diálogo del sistema
/// - Descarga directa del archivo PDF formal
class AssetReportPreviewView extends StatefulWidget {
  const AssetReportPreviewView({
    super.key,
    required this.title,
    required this.pdfBytesBuilder,
    required this.fileName,
    this.initialPaperSize = PaperSizeOption.letter,
    this.initialIsPortrait = true,
  });

  final String title;
  final Future<Uint8List> Function(PdfPageFormat format) pdfBytesBuilder;
  final String fileName;
  final PaperSizeOption initialPaperSize;
  final bool initialIsPortrait;

  @override
  State<AssetReportPreviewView> createState() => _AssetReportPreviewViewState();
}

class _AssetReportPreviewViewState extends State<AssetReportPreviewView> {
  late PaperSizeOption _paperSize;
  late bool _isPortrait;
  double _zoomFactor = 0.75;
  bool _isProcessingAction = false;

  static const double _minZoom = 0.40;
  static const double _maxZoom = 1.80;
  static const double _zoomStep = 0.15;

  @override
  void initState() {
    super.initState();
    _paperSize = widget.initialPaperSize;
    _isPortrait = widget.initialIsPortrait;
  }

  PdfPageFormat get _currentFormat {
    return _isPortrait ? _paperSize.format.portrait : _paperSize.format.landscape;
  }

  void _zoomIn() {
    setState(() {
      _zoomFactor = (_zoomFactor + _zoomStep).clamp(_minZoom, _maxZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomFactor = (_zoomFactor - _zoomStep).clamp(_minZoom, _maxZoom);
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomFactor = 0.75;
    });
  }

  Future<void> _handleDirectPrint() async {
    setState(() => _isProcessingAction = true);
    try {
      final currentFmt = _currentFormat;
      await Printing.layoutPdf(
        onLayout: (format) => widget.pdfBytesBuilder(currentFmt),
        name: widget.fileName,
        format: currentFmt,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar a impresión: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _handleDownloadPdf() async {
    setState(() => _isProcessingAction = true);
    try {
      final bytes = await widget.pdfBytesBuilder(_currentFormat);
      await UniversalFileSaver.saveFile(
        bytes: bytes,
        fileName: widget.fileName,
        mimeType: 'application/pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('PDF guardado exitosamente: ${widget.fileName}')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar PDF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 760;

    // Ancho base de página según factor de zoom
    final baseWidth = isCompact ? screenWidth * 0.95 : 820.0;
    final maxPageWidth = baseWidth * _zoomFactor;

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        actions: isCompact
            ? [
                // Acciones compactas en AppBar para móviles Android
                IconButton(
                  icon: const Icon(Icons.print_outlined, size: 22),
                  tooltip: 'Imprimir',
                  onPressed: _isProcessingAction ? null : _handleDirectPrint,
                ),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 22),
                  tooltip: 'Descargar PDF',
                  onPressed: _isProcessingAction ? null : _handleDownloadPdf,
                ),
                const SizedBox(width: 4),
              ]
            : [
                // Zoom en AppBar para Desktop/Web
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 20),
                  tooltip: 'Reducir zoom',
                  onPressed: _zoomFactor > _minZoom ? _zoomOut : null,
                ),
                InkWell(
                  onTap: _resetZoom,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    alignment: Alignment.center,
                    child: Text(
                      '${(_zoomFactor * 100).toInt()}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 20),
                  tooltip: 'Aumentar zoom',
                  onPressed: _zoomFactor < _maxZoom ? _zoomIn : null,
                ),
                const SizedBox(width: 12),
              ],
      ),
      body: Column(
        children: [
          // Barra de Control Profesional y Configuración de Impresión
          _buildControlsToolbar(isCompact: isCompact, colors: colors),

          // Visor de PDF interactivo
          Expanded(
            child: PdfPreview(
              key: ValueKey('${_paperSize.name}_${_isPortrait}'),
              build: (format) => widget.pdfBytesBuilder(_currentFormat),
              maxPageWidth: maxPageWidth,
              useActions: false, // Ocultamos barra por defecto para usar nuestra barra profesional
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: widget.fileName,
              scrollViewDecoration: BoxDecoration(
                color: Colors.grey.shade300,
              ),
              previewPageMargin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              loadingWidget: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Generando reporte PDF formal...'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsToolbar({required bool isCompact, required ColorScheme colors}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isCompact ? _buildCompactToolbar(colors) : _buildWideToolbar(colors),
    );
  }

  /// Barra de controles para pantallas grandes (Desktop/Web/Tablet)
  Widget _buildWideToolbar(ColorScheme colors) {
    return Row(
      children: [
        // Selector de Tamaño de Papel
        const Text('Papel: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PaperSizeOption>(
              value: _paperSize,
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: PaperSizeOption.values.map((opt) {
                return DropdownMenuItem(
                  value: opt,
                  child: Text(opt.label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null && val != _paperSize) {
                  setState(() => _paperSize = val);
                }
              },
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Selector de Orientación
        const Text('Orientación: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          segments: const [
            ButtonSegment(
              value: true,
              label: Text('Vertical'),
              icon: Icon(Icons.portrait, size: 16),
            ),
            ButtonSegment(
              value: false,
              label: Text('Horizontal'),
              icon: Icon(Icons.landscape, size: 16),
            ),
          ],
          selected: {_isPortrait},
          onSelectionChanged: (val) {
            setState(() => _isPortrait = val.first);
          },
        ),

        const Spacer(),

        // Botón Imprimir
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          onPressed: _isProcessingAction ? null : _handleDirectPrint,
          icon: const Icon(Icons.print_outlined, size: 16),
          label: const Text('Imprimir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),

        const SizedBox(width: 10),

        // Botón Descargar PDF
        FilledButton.icon(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: colors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: _isProcessingAction ? null : _handleDownloadPdf,
          icon: const Icon(Icons.file_download_outlined, size: 16),
          label: const Text('Descargar PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  /// Barra de controles responsiva para pantallas móviles (Android / pantallas angostas)
  Widget _buildCompactToolbar(ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Tamaño de papel dropdown
            Expanded(
              flex: 5,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PaperSizeOption>(
                    value: _paperSize,
                    isExpanded: true,
                    isDense: true,
                    style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                    items: PaperSizeOption.values.map((opt) {
                      return DropdownMenuItem(
                        value: opt,
                        child: Text(opt.label, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != _paperSize) {
                        setState(() => _paperSize = val);
                      }
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Segmented orientation
            Expanded(
              flex: 5,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Vertical'),
                    icon: Icon(Icons.portrait, size: 15),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Horiz.'),
                    icon: Icon(Icons.landscape, size: 15),
                  ),
                ],
                selected: {_isPortrait},
                onSelectionChanged: (val) {
                  setState(() => _isPortrait = val.first);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Fila de zoom y botones de acción rápida
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Zoom controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.zoom_out, size: 18),
                  tooltip: 'Reducir zoom',
                  onPressed: _zoomFactor > _minZoom ? _zoomOut : null,
                ),
                InkWell(
                  onTap: _resetZoom,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '${(_zoomFactor * 100).toInt()}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.zoom_in, size: 18),
                  tooltip: 'Aumentar zoom',
                  onPressed: _zoomFactor < _maxZoom ? _zoomIn : null,
                ),
              ],
            ),

            // Botones de acción móvil
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  onPressed: _isProcessingAction ? null : _handleDirectPrint,
                  icon: const Icon(Icons.print, size: 15),
                  label: const Text('Imprimir', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  onPressed: _isProcessingAction ? null : _handleDownloadPdf,
                  icon: const Icon(Icons.file_download_outlined, size: 15),
                  label: const Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
