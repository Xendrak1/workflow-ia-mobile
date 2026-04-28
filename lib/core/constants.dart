/// URL base del backend.
///
/// Por defecto apunta al backend local cuando se corre el emulador Android,
/// pero puede sobreescribirse en build/run con:
///
///   flutter run --dart-define=API_BASE=http://192.168.0.10:8000/api
///   flutter build apk --dart-define=API_BASE=https://workflow-18-231-117-148.sslip.io/api
///
/// Recomendaciones rápidas:
///   - Emulador Android local: http://10.0.2.2:8000/api
///   - Simulador iOS / web: http://localhost:8000/api
///   - Dispositivo físico: usa la IP LAN de tu máquina (ej. 192.168.x.x)
///   - Producción actual: https://workflow-18-231-117-148.sslip.io/api
const String kBaseUrl = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://workflow-18-231-117-148.sslip.io/api',
);
