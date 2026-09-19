import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio centralizado de notificaciones locales para Android / iOS / Web.
///
/// Configura canales de alta prioridad para:
/// - Nuevas Averías reportadas.
/// - OTs de alta prioridad o vencidas.
/// - Avisos de restablecimiento de contraseña.
/// - Notificaciones de resultado de reportes para reportadores.
class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  static const String breakdownChannelId = 'macsa_breakdowns_channel';
  static const String breakdownChannelName = 'Averías y Reportes';
  static const String breakdownChannelDesc =
      'Alertas de averías nuevas reportadas en planta';

  static const String workOrderChannelId = 'macsa_work_orders_channel';
  static const String workOrderChannelName = 'Órdenes de Trabajo';
  static const String workOrderChannelDesc =
      'Alertas de OTs de alta prioridad y vencidas';

  static const String generalChannelId = 'macsa_general_channel';
  static const String generalChannelName = 'General';
  static const String generalChannelDesc = 'Notificaciones generales del sistema';

  /// Inicializa el plugin y crea los canales de Android.
  Future<void> initialize({
    void Function(NotificationResponse)? onSelectNotification,
  }) async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: onSelectNotification,
      );

      // Crear canales de notificación específicos en Android
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            breakdownChannelId,
            breakdownChannelName,
            description: breakdownChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            workOrderChannelId,
            workOrderChannelName,
            description: workOrderChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            generalChannelId,
            generalChannelName,
            description: generalChannelDesc,
            importance: Importance.defaultImportance,
            playSound: true,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('LocalNotificationService initialize error: $e');
    }
  }

  /// Solicita permisos de notificación al usuario (especialmente Android 13+ e iOS).
  Future<bool?> requestPermissions() async {
    try {
      if (kIsWeb) return null;

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        return await androidPlugin.requestNotificationsPermission();
      }

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        return await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('LocalNotificationService requestPermissions error: $e');
    }
    return null;
  }

  /// Muestra una notificación genérica en la barra del sistema.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = generalChannelId,
    String channelName = generalChannelName,
    String channelDescription = generalChannelDesc,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
  }) async {
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('LocalNotificationService showNotification error: $e');
    }
  }

  /// Dispara notificación nativa para un reporte de avería nuevo.
  Future<void> showBreakdownNotification({
    required String reportId,
    required String assetId,
    required String assetName,
    required String reportedBy,
    String? areaId,
  }) async {
    final title = '🚨 Nueva Avería: $assetId';
    final areaText = areaId != null ? ' (Área $areaId)' : '';
    final body = '$reportedBy reportó falla en $assetName$areaText.';
    final id = reportId.hashCode.abs() % 100000;

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: 'breakdown:$reportId',
      channelId: breakdownChannelId,
      channelName: breakdownChannelName,
      channelDescription: breakdownChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
    );
  }

  /// Dispara notificación nativa para una OT de alta prioridad o urgente.
  Future<void> showWorkOrderNotification({
    required String orderId,
    required String correlative,
    required String assetName,
    required String description,
  }) async {
    final title = '⚠️ OT Alta Prioridad: $correlative';
    final body = '$assetName — $description';
    final id = orderId.hashCode.abs() % 100000;

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: 'work_order:$orderId',
      channelId: workOrderChannelId,
      channelName: workOrderChannelName,
      channelDescription: workOrderChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
    );
  }

  /// Dispara notificación nativa para el reportador cuando su avería fue atendida/rechazada.
  Future<void> showReportOutcomeNotification({
    required String reportId,
    required String assetId,
    required bool isAccepted,
    String? workOrderId,
    String? rejectionReason,
  }) async {
    final title = isAccepted ? '✅ Reporte Atendido' : '❌ Reporte Rechazado';
    final body = isAccepted
        ? 'Tu reporte de $assetId fue atendido (OT ${workOrderId ?? ''}).'
        : 'Tu reporte de $assetId fue rechazado. Motivo: ${rejectionReason ?? '—'}';
    final id = reportId.hashCode.abs() % 100000;

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: 'my_report:$reportId',
      channelId: generalChannelId,
      channelName: generalChannelName,
      channelDescription: generalChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// Dispara notificación nativa al administrador para restablecimiento de contraseña.
  Future<void> showPasswordResetNotification({
    required String username,
    String? displayName,
  }) async {
    final title = '🔑 Solicitud de Contraseña';
    final body =
        '${displayName ?? username} (@$username) solicitó una clave temporal.';
    final id = username.hashCode.abs() % 100000;

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: 'password_reset:$username',
      channelId: generalChannelId,
      channelName: generalChannelName,
      channelDescription: generalChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
  }
}
