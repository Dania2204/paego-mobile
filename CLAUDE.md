# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es

App **móvil** Flutter de PAEGo (paquete `opaego`), la contraparte de la plataforma web Django que
vive en `../oPAEGo` (API REST + panel del administrador). Repo remoto:
`github.com/Dania2204/trabajo_Final_Flutter` (trabajo por PRs desde `feature/setup`).

Según el documento de tesis (`../oPAEGo/docs/`), la app la usan el **conductor** y la
**institución educativa**. Está conectada a la API de `oPAEGo` (JWT); los usuarios se crean en la
web, la app solo inicia sesión. Contrato de la API: `/api/schema/` del backend.

## Comandos

```bash
flutter pub get
flutter run                      # requiere un archivo .env en la raíz (ver abajo)
flutter run -d chrome            # web: sqflite vía sqflite_common_ffi_web
flutter analyze                  # lints de flutter_lints
flutter test                     # modelos, cliente JWT y cola sin conexión
flutter test test/api_y_sincronizacion_test.dart --plain-name "sin red"
dart run flutter_launcher_icons  # regenerar íconos desde assets/images/pae_logo.png
```

- `.env` está declarado como asset en `pubspec.yaml`: si no existe, el build falla. Copiar
  `.env.example` → `.env` (está en `.gitignore`). `PAEGO_API_URL` = URL del backend
  (Railway, `http://10.0.2.2:8000` en emulador Android, `http://localhost:8000` en Chrome; para
  Chrome el backend necesita `CORS_ALLOWED_ORIGINS` con el origen de la app).
- Las pruebas de sqflite usan `sqflite_common_ffi` (dev dependency) y `http/testing.dart` MockClient.
  Cada archivo de pruebas que toca SQLite fija su propio `DatabaseHelper.nombreArchivo` (flutter test
  corre los archivos en paralelo). Las pruebas de widgets ponen `S.guardarTextosNuevos = false`
  (si no, `S.text` escribe en SQLite y quedan temporizadores pendientes). JSON real de un envío:
  `test/datos_prueba.dart`.

## Arquitectura

- `lib/main.dart`: sqflite (FFI en web), `.env`, `initializeDateFormatting('es')`, textos de Supabase.
- Rutas con nombre en `lib/core/router/app_router.dart` (`/`, `/login`, `/home` con `AppUser`).
  `HomeShell` arranca los servicios del usuario (`AuthService.iniciarServicios`), pide la
  aceptación de la Ley 1581 (RNF-11) y muestra `BarraSincronizacion`. Sin gestor de estado:
  singletons + `ValueNotifier`.

### Integración con oPAEGo (`lib/data/`)
- `remote/api_client.dart`: HTTP con JWT. Tokens en SharedPreferences; ante 401 renueva con el
  refresh (rota en cada uso, una renovación a la vez) y reintenta. Excepciones:
  `SinConexionException`, `SesionVencidaException` (refresh de 30 min vencido → volver a ingresar),
  `ApiException`.
- `repositories/auth_service.dart`: login `POST /api/auth/token/`, perfil guardado para abrir sin
  red, logout revoca el refresh (el backend saca al conductor del mapa en vivo).
- `sync/sync_service.dart`: **toda acción se encola** en la tabla SQLite `operaciones` con
  `uuid_cliente` + `ocurrido_en` y se envía a `POST /api/sincronizacion/lote/` (idempotente;
  RF-38). Reintenta al volver la red (connectivity_plus) y cada 30 s. Las rechazadas quedan con su
  motivo (pantalla Informes). Las fotos viajan en base64 dentro del JSON y se borran tras enviarse.
- `repositories/envio_repository.dart`: `GET /api/envios/` (30 días) con caché `envios_cache`, y
  acciones salida/llegada/ubicación/novedad/confirmar → cola. Aplica las operaciones pendientes
  sobre la caché (cambios optimistas) y recarga del servidor cuando el lote se aplica.
- `services/rastreo_service.dart`: GPS (`location`). Conductor: posición en vivo cada 3 s a
  `POST /api/monitoreo/mi-posicion/` (efímera, la ve el admin en "Hoy" de la web) + punto del
  recorrido (RF-21) cada `intervalo_ubicacion_seg` del servidor para envíos en tránsito (encolado).
  **Segundo plano** (conductor, durante un envío en tránsito): el mapa muestra un aviso → diálogo
  explicativo → `permission_handler` pide "Permitir todo el tiempo" *solo* (Android 11+ ignora la
  petición combinada que hace el plugin `location`) → `enableBackgroundMode` arranca el servicio en
  primer plano con notificación (`res/drawable/ic_stat_paego.xml`, protegido en `res/raw/keep.xml`).
  Se recuerda en `paego_segundo_plano` y se reactiva solo en cada sesión; `detener()` lo apaga.
  `permission_handler` fijado en ^12 (la 13 no compila con el Gradle del proyecto). En iOS, al
  generar el `Podfile`, definir `PERMISSION_LOCATION=1` y `PERMISSION_NOTIFICATIONS=1`.
  Si el GPS está apagado o sin permiso al
  iniciar, revisa cada 5 s y arranca solo (no repite "activar GPS"; el permiso lo pide una sola vez si nunca se pidió); `test/rastreo_test.dart` usa un
  `Location` falso (`usarLocation`).
- Modelos: `models/envio.dart` envuelve el JSON del `EnvioSerializer` (estados
  `ASIGNADO|EN_TRANSITO|ENTREGADO|CON_NOVEDAD|CANCELADO`). Roles: `CONDUCTOR→driver`,
  `INSTITUCION→rector`, `ADMINISTRADOR→admin` (`UserRoleX.fromBackend`); los getters de
  `user_role.dart` solo muestran/ocultan UI, los permisos reales los aplica la API.
- UI de envíos compartida en `lib/features/envios/envio_widgets.dart` (detalle, acciones por rol,
  novedad, confirmar recepción con código de 6 dígitos). Mapa, dashboard e informes leen de
  `EnvioRepository`/`SyncService`. Los usuarios se crean en la web (no hay pantalla de personal).
- SQLite `paego.db` versión 6: `app_texts`, `envios_cache`, `operaciones`. La v6 borra las tablas
  del modo local anterior a la API (`users`, `delivery_orders`, …).

### Mapa base (`lib/core/config/mapa_base.dart`)
- `flutter_map` (código abierto) con teselas del servicio **Static Basemap Tiles de ArcGIS
  Location Platform** si `ARCGIS_API_KEY` está en `.env`; sin clave, OpenStreetMap. Teselas de
  512 px → `tileSize: 512` + `zoomOffset: -1`; URL `.../v1/{familia}/{estilo}/static/tile/{z}/{y}/{x}?token=`
  (fila antes que columna). Capa gratuita: 2 M teselas/mes, sin tope automático → restringir la
  clave en location.arcgis.com. Atribución "Powered by Esri" obligatoria. El estilo elegido se
  guarda en SharedPreferences (`paego_estilo_mapa`). El SDK oficial `arcgis_maps` no se usa:
  es solo Android/iOS (no web) y exige licencia para producción.
- Debug Android permite HTTP sin TLS (`android/app/src/debug/AndroidManifest.xml`) para probar
  contra el backend local con `adb reverse tcp:8000 tcp:8000` y `PAEGO_API_URL=http://localhost:8000`.

### Otros
- Textos bilingües (`lib/core/l10n/app_strings.dart`, clase `S`): `S.text('clave', 'es', 'en')`
  o `_t('es','en')` (clave = hash FNV del texto: cambiar el texto cambia la clave). Se sincronizan
  con la tabla Supabase `app_texts`.
- Nutrición: llama a Gemini con `GEMINI_API_KEY`/`GEMINI_MODEL` del `.env`
  (`lib/core/config/gemini_config.dart`). La clave viaja en el APK: a futuro, pasar por el backend.

## CI/CD (`.github/`)

- Secreto opcional `ARCGIS_API_KEY` (mapas de ArcGIS en los builds de CI y release).
- `ci.yml`: `flutter analyze` (cualquier aviso, incluso info, bloquea), `dart format
  --set-exit-if-changed lib test` (bloquea: formatear antes de commitear), `flutter test --coverage`
  con un archivo generado que importa todo `lib/` (cobertura real, con pantallas) y mínimo
  `COBERTURA_MINIMA` (25 %; subirlo al agregar pruebas), builds web y
  APK como artefactos. Crea `.env` con `PAEGO_API_URL` (variable de repo opcional).
- `release.yml`: con un tag `v*` compila el APK (firma debug) y lo publica en un GitHub Release.
- Dependabot para pub y GitHub Actions.

## Pendientes conocidos

- La clave de Gemini que estuvo versionada en `.env.example` sigue en el historial de git: rotarla.

## Reglas del usuario

- Git: commits en ramas de feature (no en `main`), Conventional Commits en español, autor Steven,
  nunca atribución a Claude (hook `commit-msg`). Preguntar antes de `git push` o abrir PR: el
  remoto es de la compañera (Dania2204).
- Interfaz y mensajes en español (con traducción inglés vía `S`).
