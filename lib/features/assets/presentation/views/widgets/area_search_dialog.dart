import 'package:flutter/material.dart';

import '../../../domain/entities/area.dart';

/// Diálogo modal con buscador en tiempo real para selección de Área.
class AreaSearchDialog extends StatefulWidget {
  const AreaSearchDialog({
    super.key,
    required this.areas,
    this.currentAreaId,
  });

  final List<Area> areas;
  final String? currentAreaId;

  /// Abre el diálogo modal y retorna el ID del área seleccionada (o null para 'Todas las Áreas').
  static Future<String?> show(
    BuildContext context, {
    required List<Area> areas,
    String? currentAreaId,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (_) => AreaSearchDialog(
        areas: areas,
        currentAreaId: currentAreaId,
      ),
    );
  }

  @override
  State<AreaSearchDialog> createState() => _AreaSearchDialogState();
}

class _AreaSearchDialogState extends State<AreaSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.areas.where((a) {
      if (_query.isEmpty) return true;
      final name = a.name.toLowerCase();
      final id = a.id.toLowerCase();
      final costCenter = a.costCenter.toLowerCase();
      return name.contains(_query) ||
          id.contains(_query) ||
          costCenter.contains(_query);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.apartment_outlined, size: 22, color: Color(0xFF0284C7)),
                      SizedBox(width: 10),
                      Text(
                        'Seleccionar Área',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(widget.currentAreaId),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // Campo de búsqueda en vivo
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, código o centro de costo...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                  ),
                ),
              ),
            ),

            // Opción: Todas las Áreas
            if (_query.isEmpty) ...[
              InkWell(
                onTap: () => Navigator.of(context).pop(''),
                child: Container(
                  color: widget.currentAreaId == null || widget.currentAreaId!.isEmpty
                      ? const Color(0xFFF0F9FF)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.domain_outlined, size: 18, color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Todas las Áreas',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Consolidado de toda la planta',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      if (widget.currentAreaId == null || widget.currentAreaId!.isEmpty)
                        const Icon(Icons.check_circle, size: 18, color: Color(0xFF0284C7)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ],

            // Lista filtrada de áreas
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, size: 36, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No se encontró ningún área con "$_query"',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final area = filtered[index];
                        final isSelected = widget.currentAreaId == area.id;

                        return InkWell(
                          onTap: () => Navigator.of(context).pop(area.id),
                          child: Container(
                            color: isSelected ? const Color(0xFFF0F9FF) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    area.id,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    area.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${area.assetCounter} eq.',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle, size: 18, color: Color(0xFF0284C7)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
