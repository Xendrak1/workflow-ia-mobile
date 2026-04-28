# Workflow IA — App móvil

Aplicación móvil en Flutter para el sistema **Workflow IA**. Está pensada para
los dos perfiles operativos del sistema:

- **Funcionarios**: monitor de tareas, llenado de formularios dinámicos,
  carga de evidencia (foto, archivo, nota textual) y transcripción por audio
  para apoyar el llenado asistido.
- **Administradores / supervisores**: monitoreo del flujo completo, vista
  de cuellos de botella con análisis IA, y consulta de las políticas de
  negocio publicadas.

> Este proyecto es solo el cliente móvil. El backend (FastAPI + MongoDB +
> IA/transcripción) vive en `../proyecto-workflow-ia/backend` y debe estar en línea
> antes de iniciar la app.

---

## Stack

- **Flutter 3.x** (Dart `^3.11.3`)
- **go_router** para navegación declarativa
- **provider** para inyección de dependencias y estado
- **http** para llamadas REST
- **shared_preferences** para sesión persistente
- **image_picker / file_picker** para evidencia
- **record** para grabación de audio
- **intl** para localización mínima

---

## Estructura

```
lib/
├── main.dart                    # Bootstrap + MultiProvider
├── core/
│   ├── api_service.dart         # Cliente HTTP tipado del backend
│   ├── app_router.dart          # GoRouter + redirección por sesión/rol
│   ├── constants.dart           # kBaseUrl (configurable vía --dart-define)
│   ├── session_service.dart     # Sesión persistida (token, rol, depto…)
│   ├── theme.dart               # Tema oscuro Material 3
│   └── models/
│       ├── ai_model.dart        # TaskFormFillResult (asistente IA)
│       ├── analytics_model.dart # Summary, BottleneckData, CriticalNode
│       ├── policy_model.dart    # Policy, PolicyNode, FormField
│       └── task_model.dart      # Task, EvidenceItem
├── pages/
│   ├── splash/                  # Decide ruta inicial según rol
│   ├── login/                   # Autenticación contra /api/auth/login
│   ├── inbox/                   # Monitor de tareas del funcionario
│   ├── task_detail/             # Detalle + form dinámico + evidencias + IA
│   └── admin/
│       ├── admin_home_page.dart # Tabs Monitoreo / Políticas
│       ├── analytics_panel.dart # Resumen + cuellos de botella IA
│       ├── policies_panel.dart  # Listado de políticas publicadas
│       └── policy_detail_page.dart  # Detalle por carriles y nodos
└── widgets/
    ├── ai_dictation_sheet.dart  # Modal del asistente IA (texto + audio)
    ├── dynamic_form_field.dart  # Render dinámico por field_type
    ├── empty_state.dart
    ├── status_badge.dart
    └── task_card.dart
```

---

## Configuración del backend

Por defecto la app apunta a `http://10.0.2.2:8000/api` (loopback del
emulador Android). Se puede sobrescribir al compilar/correr con
`--dart-define`:

```bash
# Producción actual (default)
flutter run

# Simulador iOS / Web
flutter run --dart-define=API_BASE=http://localhost:8000/api

# Dispositivo físico en LAN
flutter run --dart-define=API_BASE=http://192.168.0.10:8000/api

# Emulador Android local
flutter run --dart-define=API_BASE=http://10.0.2.2:8000/api

# Producción
flutter build apk --release \
  --dart-define=API_BASE=https://workflow-18-231-117-148.sslip.io/api
```

El backend debe estar levantado:

```bash
cd ../proyecto-workflow-ia/backend
python run.py
```

Asegurate de tener el `.env` con `MONGODB_URI` y `JWT_SECRET`
configurados. Si además usarás Gemini para sugerencias y analítica,
configura también `GEMINI_API_KEY`.

---

## Permisos

### Android (`android/app/src/main/AndroidManifest.xml`)

- `INTERNET`
- `RECORD_AUDIO` — para capturar audio del funcionario
- `usesCleartextTraffic="true"` + `network_security_config.xml` para
  permitir HTTP a `10.0.2.2` y `localhost` en desarrollo.

### iOS (`ios/Runner/Info.plist`)

- `NSMicrophoneUsageDescription` — dictado IA
- `NSCameraUsageDescription` — evidencia fotográfica
- `NSPhotoLibraryUsageDescription` — evidencia desde galería

---

## Comandos rápidos

```bash
flutter pub get        # Instalar dependencias
flutter analyze        # Linter (debe pasar sin errores)
flutter test           # Test mínimo del tema
flutter run            # Lanzar en el dispositivo activo
```

---

## Endpoints REST consumidos

| Método | Endpoint                          | Uso                                |
|--------|-----------------------------------|------------------------------------|
| POST   | `/api/auth/login`                 | Login y obtención de JWT           |
| GET    | `/api/tasks`                      | Lista de tareas (filtra en cliente)|
| GET    | `/api/tasks/{id}`                 | Detalle de tarea                   |
| PUT    | `/api/tasks/{id}`                 | Guardar borrador (form + obs)      |
| POST   | `/api/tasks/{id}/complete`        | Marcar completada y enrutar        |
| POST   | `/api/tasks/{id}/evidences`       | Subir evidencia (base64)           |
| GET    | `/api/policies`                   | Listar políticas (admin)           |
| GET    | `/api/policies/{id}`              | Detalle de política                |
| GET    | `/api/analytics/summary`          | KPIs de flujo                      |
| GET    | `/api/analytics/bottlenecks`      | Análisis de cuellos de botella IA  |
| POST   | `/api/ai/task-form-fill`          | Asistente IA — texto               |
| POST   | `/api/ai/transcribe-audio`        | Transcribe audio a texto (Vosk)    |
| POST   | `/api/ai/task-form-fill-local`    | Extracción local desde texto       |

---

## Roles soportados

La app distingue por el campo `role` del JWT:

- `funcionario` → va a `/inbox`
- `administrador` → va a `/admin`
- `supervisor` → va a `/inbox` con acceso al panel `/admin`
- `cliente` → va a `/inbox` (vista limitada)

---

## Asistente IA y audio

El botón "Asistente IA · Dictado" en el detalle de tarea abre
un modal con tres caminos:

1. **Texto**: el funcionario escribe un informe libre y la IA llena los
   campos clave del formulario.
2. **Extraer del texto**: aplica reglas locales si quieres una opción
   determinística sin depender de Gemini.
3. **Audio**: graba un audio (codec `aac`, 16 kHz mono), lo manda a
   `/api/ai/transcribe-audio`, y el backend devuelve la transcripción para
   pegarla en el textarea antes de generar o extraer.
4. **Preview**: muestra resumen, transcripción, observaciones y los
   valores propuestos. El usuario puede aceptar para mergearlos en el
   formulario o reintentar.

Si Gemini falla (timeout, cuota o key inválida), el backend devuelve
automáticamente un fallback estructurado. Para transcripción de audio, la
app usa el flujo dedicado de `/api/ai/transcribe-audio` y luego permite
decidir si se genera con IA o se extrae localmente.
