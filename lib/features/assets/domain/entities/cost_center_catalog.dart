class CostCenterInfo {
  final String code; // Ej: "001", "002"
  final String id;   // Ej: "37", "38"
  final String name; // Ej: "ADMINISTRACION"

  const CostCenterInfo({
    required this.code,
    required this.id,
    required this.name,
  });

  String get areaId => 'A$code';
  String get formattedCostCenter => 'CC-$id';
  String get displayName => '[$areaId] $name (CC-$id)';
}

/// Catálogo oficial de los 30 Centros de Costo de la empresa.
const List<CostCenterInfo> costCenterCatalog = [
  CostCenterInfo(code: '001', id: '37', name: 'ADMINISTRACION'),
  CostCenterInfo(code: '002', id: '38', name: 'AREA DE DESPACHO'),
  CostCenterInfo(code: '003', id: '39', name: 'EMPAQUE - MASTERIZADO'),
  CostCenterInfo(code: '004', id: '40', name: 'CAFETERIA'),
  CostCenterInfo(code: '005', id: '41', name: 'CLASIFICADO'),
  CostCenterInfo(code: '006', id: '42', name: 'COCINADO'),
  CostCenterInfo(code: '007', id: '43', name: 'CONTABILIDAD'),
  CostCenterInfo(code: '008', id: '44', name: 'DESCABEZADO'),
  CostCenterInfo(code: '009', id: '45', name: 'EMPAQUE BLOCK'),
  CostCenterInfo(code: '010', id: '46', name: 'EMPAQUE IQF'),
  CostCenterInfo(code: '011', id: '47', name: 'GERENCIA'),
  CostCenterInfo(code: '012', id: '48', name: 'IMPORT & EXPORT'),
  CostCenterInfo(code: '013', id: '49', name: 'INOCUIDAD'),
  CostCenterInfo(code: '014', id: '50', name: 'RECEPCION'),
  CostCenterInfo(code: '015', id: '51', name: 'LABORATORIO'),
  CostCenterInfo(code: '016', id: '52', name: 'LAVANDERIA'),
  CostCenterInfo(code: '017', id: '53', name: 'MANTENIMIENTO'),
  CostCenterInfo(code: '018', id: '54', name: 'PLANTA DE HIELO'),
  CostCenterInfo(code: '019', id: '55', name: 'POES'),
  CostCenterInfo(code: '020', id: '56', name: 'AREA ENVIO-PRODUCTO TERMINADO'),
  CostCenterInfo(code: '021', id: '57', name: 'RECEPCION'),
  CostCenterInfo(code: '022', id: '58', name: 'RECURSOS HUMANOS'),
  CostCenterInfo(code: '023', id: '59', name: 'SALMUERA'),
  CostCenterInfo(code: '024', id: '60', name: 'SALUD & SEGURIDAD OCUPACIONAL'),
  CostCenterInfo(code: '025', id: '61', name: "TIC'S"),
  CostCenterInfo(code: '026', id: '62', name: 'VIGILANCIA'),
  CostCenterInfo(code: '027', id: '63', name: 'PELADO'),
  CostCenterInfo(code: '028', id: '64', name: 'TRATAMIENTO-PELADO'),
  CostCenterInfo(code: '029', id: '65', name: 'LIMPIEZA -EXTERIORES'),
  CostCenterInfo(code: '030', id: '98', name: 'PRODUCCION'),
];
