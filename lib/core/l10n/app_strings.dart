import 'package:flutter/foundation.dart';

import '../../data/datasources/database_helper.dart';

/// Sistema de localización bilingüe (Español / English).
/// Cambia el idioma con [S.setLocale] y todos los widgets se actualizan.
abstract class S {
  // Locale activo: 'es' o 'en'
  static String _locale = 'es';
  static Map<String, Map<String, String>> _dbTexts = {};
  static final Set<String> _queuedSeeds = {};
  static final List<Future<void>> _pendingSeedWrites = [];

  /// Las pruebas de widgets lo apagan: guardar cada texto nuevo en SQLite
  /// deja temporizadores pendientes en el reloj simulado de flutter_test.
  @visibleForTesting
  static bool guardarTextosNuevos = true;
  static String get locale => _locale;
  static void setLocale(String l) => _locale = l == 'en' ? 'en' : 'es';
  static bool get isSpanish => _locale == 'es';

  static Future<void> loadFromDatabase() async {
    _dbTexts = await DatabaseHelper.instance.getAppTexts();
  }

  static Future<void> seedDefaults() async {
    final accessors = <String Function()>[
      () => appName,
      () => appTagline,
      () => splashLoading,
      () => loginTitle,
      () => loginSubtitle,
      () => loginEmail,
      () => loginPassword,
      () => loginButton,
      () => loginNoAccount,
      () => loginRegister,
      () => loginForgot,
      () => loginRequired,
      () => loginInvalidEmail,
      () => loginInvalidCredentials,
      () => loginRegistrationDisabled,
      () => registerTitle,
      () => registerSubtitle,
      () => registerFullName,
      () => registerEmail,
      () => registerPhone,
      () => registerPassword,
      () => registerConfirmPassword,
      () => registerRole,
      () => registerIdNumber,
      () => registerInstitution,
      () => registerButton,
      () => registerHaveAccount,
      () => registerSignIn,
      () => registerPasswordMismatch,
      () => registerSuccess,
      () => registerPhotoUpload,
      () => registerDisabledTitle,
      () => registerDisabledMessage,
      () => registerBackToLogin,
      () => roleSuperAdmin,
      () => roleAdmin,
      () => roleRector,
      () => roleDriver,
      () => roleDescSuperAdmin,
      () => roleDescAdmin,
      () => roleDescRector,
      () => roleDescDriver,
      () => dashboardWelcome,
      () => dashboardActiveDeliveries,
      () => dashboardPendingOrders,
      () => dashboardDriversOnline,
      () => dashboardReportsToday,
      () => dashboardQuickActions,
      () => dashboardRecentActivity,
      () => navHome,
      () => navMap,
      () => navMessages,
      () => navReports,
      () => navProfile,
      () => navNutrition,
      () => mapTitle,
      () => mapSubtitle,
      () => mapMyLocation,
      () => mapAddSchool,
      () => mapSchoolName,
      () => mapSchoolAddress,
      () => mapSaveLocation,
      () => mapSelectOnMap,
      () => mapNoVehicles,
      () => mapStartRoute,
      () => mapStopRoute,
      () => mapSendLocation,
      () => mapVehiclesActive,
      () => orderTitle,
      () => orderAvailable,
      () => orderMyActive,
      () => orderStatusPending,
      () => orderStatusAssigned,
      () => orderStatusEnRoute,
      () => orderStatusDelivered,
      () => orderClaimButton,
      () => orderStartButton,
      () => orderCompleteButton,
      () => orderNoOrders,
      () => orderSchool,
      () => orderPickup,
      () => orderDistance,
      () => reportTitle,
      () => reportNew,
      () => reportCondition,
      () => reportConditionGood,
      () => reportConditionFair,
      () => reportConditionPoor,
      () => reportNotes,
      () => reportPhotos,
      () => reportAddPhoto,
      () => reportSubmit,
      () => reportSubmitted,
      () => reportPendingSync,
      () => reportSynced,
      () => reportNoReports,
      () => reportSchool,
      () => reportDate,
      () => reportBy,
      () => reportViewPhotos,
      () => personnelTitle,
      () => personnelAdd,
      () => personnelEmpty,
      () => personnelDelete,
      () => personnelDeleteConfirm,
      () => personnelEdit,
      () => personnelAdminOnly,
      () => personnelCreated,
      () => personnelCannotDeleteSelf,
      () => messagesTitle,
      () => messagesTypeHere,
      () => messagesSend,
      () => messagesEmpty,
      () => settingsTitle,
      () => profileTitle,
      () => profileEditPhoto,
      () => profileLogout,
      () => profileLogoutConfirm,
      () => profilePrivacy,
      () => profileNotifications,
      () => settingsTheme,
      () => settingsLanguage,
      () => settingsSync,
      () => settingsSyncing,
      () => settingsSyncDone,
      () => syncOffline,
      () => syncOnline,
      () => cancel,
      () => confirm,
      () => save,
      () => update,
      () => delete,
      () => edit,
      () => close,
      () => retry,
      () => loading,
      () => error,
      () => required,
      () => comingSoon,
      () => pageNotFound,
      () => routeNotFound,
      () => yes,
      () => no,
      () => search,
      () => noResults,
      () => viewAll,
      () => unknown,
    ];

    for (final read in accessors) {
      read();
    }

    if (_pendingSeedWrites.isNotEmpty) {
      await Future.wait(List<Future<void>>.from(_pendingSeedWrites));
      _pendingSeedWrites.clear();
    }
  }

  static String text(String key, String es, String en) {
    _seedMissing(key, 'es', es);
    _seedMissing(key, 'en', en);
    return _dbTexts[key]?[_locale] ?? (isSpanish ? es : en);
  }

  static String _t(String es, String en) => text(_keyFor(es, en), es, en);

  static String _keyFor(String es, String en) {
    final source = '$es|$en';
    var hash = 0x811c9dc5;
    for (final unit in source.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final readable = en
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'ui.${readable.isEmpty ? 'text' : readable}.$hash';
  }

  static void _seedMissing(String key, String locale, String value) {
    final values = _dbTexts.putIfAbsent(key, () => <String, String>{});
    if (values.containsKey(locale)) return;

    values[locale] = value;
    if (!guardarTextosNuevos) return;
    final seedKey = '$key:$locale';
    if (!_queuedSeeds.add(seedKey)) return;

    _pendingSeedWrites.add(
      DatabaseHelper.instance.upsertAppText(
        key: key,
        locale: locale,
        value: value,
      ),
    );
  }

  // ── App ───────────────────────────────────────────────────────────────────
  static String get appName => _t('PAEGo', 'PAEGo');
  static String get appTagline =>
      _t('Programa de Alimentación Escolar', 'School Feeding Programme');

  // ── Splash ────────────────────────────────────────────────────────────────
  static String get splashLoading => _t('Cargando…', 'Loading…');

  // ── Login ─────────────────────────────────────────────────────────────────
  static String get loginTitle => _t('Bienvenido', 'Welcome back');
  static String get loginSubtitle =>
      _t('Inicia sesión para continuar', 'Sign in to continue');
  static String get loginEmail => _t('Usuario o correo', 'Username or email');
  static String get loginPassword => _t('Contraseña', 'Password');
  static String get loginButton => _t('Iniciar sesión', 'Sign in');
  static String get loginNoAccount => _t('¿Necesitas acceso?', 'Need access?');
  static String get loginRegister => _t('Contacta al admin', 'Contact admin');
  static String get loginForgot =>
      _t('¿Olvidaste tu contraseña?', 'Forgot password?');
  static String get loginRequired =>
      _t('Este campo es obligatorio', 'This field is required');
  static String get loginInvalidEmail =>
      _t('Ingresa un correo válido', 'Enter a valid email');
  static String get loginInvalidCredentials =>
      _t('Usuario o contraseña inválidos', 'Invalid email or password');
  static String get loginRegistrationDisabled => _t(
    'El registro solo lo puede hacer un administrador.',
    'User registration is handled only by an administrator.',
  );

  // ── Register ──────────────────────────────────────────────────────────────
  static String get registerTitle => _t('Crear cuenta', 'Create account');
  static String get registerSubtitle =>
      _t('Únete a la red PAEGo', 'Join the PAEGo network');
  static String get registerFullName => _t('Nombre completo', 'Full name');
  static String get registerEmail => _t('Correo electrónico', 'Email');
  static String get registerPhone => _t('Número de teléfono', 'Phone number');
  static String get registerPassword => _t('Contraseña', 'Password');
  static String get registerConfirmPassword =>
      _t('Confirmar contraseña', 'Confirm password');
  static String get registerRole => _t('Rol', 'Role');
  static String get registerIdNumber =>
      _t('Número de identificación', 'ID number');
  static String get registerInstitution =>
      _t('Institución (opcional)', 'Institution (optional)');
  static String get registerButton => _t('Crear cuenta', 'Create account');
  static String get registerHaveAccount =>
      _t('¿Ya tienes cuenta?', 'Already have an account?');
  static String get registerSignIn => _t('Iniciar sesión', 'Sign in');
  static String get registerPasswordMismatch =>
      _t('Las contraseñas no coinciden', 'Passwords do not match');
  static String get registerSuccess =>
      _t('Cuenta creada exitosamente', 'Account created successfully');
  static String get registerPhotoUpload => _t('Subir foto', 'Upload photo');
  static String get registerDisabledTitle =>
      _t('Registro deshabilitado', 'Registration disabled');
  static String get registerDisabledMessage => _t(
    'Solo un administrador puede crear cuentas.',
    'Only an administrator can create user accounts.',
  );
  static String get registerBackToLogin =>
      _t('Volver al inicio de sesión', 'Back to sign in');

  // ── Roles ─────────────────────────────────────────────────────────────────
  static String get roleSuperAdmin => _t('Super Admin', 'Super Admin');
  static String get roleAdmin => _t('Admin', 'Admin');
  static String get roleRector => _t('Institución educativa', 'School');
  static String get roleDriver => _t('Conductor', 'Driver');

  static String get roleDescSuperAdmin => _t(
    'Acceso total — ver y gestionar todo.',
    'Full system access — view and manage everything.',
  );
  static String get roleDescAdmin => _t(
    'Consulta los envíos; la gestión se hace en la plataforma web.',
    'View deliveries; management is done on the web platform.',
  );
  static String get roleDescRector => _t(
    'Sigue los envíos hacia tu sede y confirma la recepción.',
    'Track deliveries to your school and confirm reception.',
  );
  static String get roleDescDriver => _t(
    'Registra salida, recorrido y llegada de tus envíos.',
    'Record departure, route and arrival of your deliveries.',
  );

  // ── Home / Dashboard ──────────────────────────────────────────────────────
  static String get dashboardWelcome => _t('Buenos días', 'Good morning');
  static String get dashboardActiveDeliveries =>
      _t('Entregas activas', 'Active deliveries');
  static String get dashboardPendingOrders =>
      _t('Pedidos pendientes', 'Pending orders');
  static String get dashboardDriversOnline =>
      _t('Conductores activos', 'Drivers online');
  static String get dashboardReportsToday =>
      _t('Informes hoy', 'Reports today');
  static String get dashboardQuickActions =>
      _t('Acciones rápidas', 'Quick actions');
  static String get dashboardRecentActivity =>
      _t('Actividad reciente', 'Recent activity');

  // ── Navigation ────────────────────────────────────────────────────────────
  static String get navHome => _t('Inicio', 'Home');
  static String get navMap => _t('Mapa', 'Map');
  static String get navMessages => _t('Mensajes', 'Messages');
  static String get navReports => _t('Informes', 'Reports');
  static String get navProfile => _t('Perfil', 'Profile');
  static String get navNutrition => _t('Nutrición', 'Nutrition');

  // ── Map ───────────────────────────────────────────────────────────────────
  static String get mapTitle => _t('Mapa en vivo', 'Live Map');
  static String get mapSubtitle =>
      _t('Seguimiento en tiempo real', 'Real-time tracking');
  static String get mapMyLocation =>
      _t('Mi ubicación actual', 'My current location');
  static String get mapAddSchool =>
      _t('Agregar escuela', 'Add school location');
  static String get mapSchoolName => _t('Nombre de la escuela', 'School name');
  static String get mapSchoolAddress => _t('Dirección', 'Address');
  static String get mapSaveLocation => _t('Guardar ubicación', 'Save location');
  static String get mapSelectOnMap =>
      _t('Toca el mapa para colocar el pin', 'Tap on the map to place pin');
  static String get mapNoVehicles =>
      _t('Sin vehículos rastreados', 'No vehicles currently tracked');
  static String get mapStartRoute => _t('Iniciar ruta', 'Start route');
  static String get mapStopRoute => _t('Detener ruta', 'Stop route');
  static String get mapSendLocation =>
      _t('Enviando ubicación…', 'Sending location…');
  static String get mapVehiclesActive =>
      _t('vehículos activos', 'vehicles active');

  // ── Deliveries / Orders ───────────────────────────────────────────────────
  static String get orderTitle => _t('Pedidos', 'Orders');
  static String get orderAvailable =>
      _t('Pedidos disponibles', 'Available orders');
  static String get orderMyActive => _t('Mi pedido activo', 'My active order');
  static String get orderStatusPending => _t('Pendiente', 'Pending');
  static String get orderStatusAssigned => _t('Asignado', 'Assigned');
  static String get orderStatusEnRoute => _t('En camino', 'En route');
  static String get orderStatusDelivered => _t('Entregado', 'Delivered');
  static String get orderClaimButton => _t('Aceptar pedido', 'Accept order');
  static String get orderStartButton => _t('Iniciar entrega', 'Start delivery');
  static String get orderCompleteButton =>
      _t('Marcar entregado', 'Mark delivered');
  static String get orderNoOrders =>
      _t('Sin pedidos disponibles', 'No orders available');
  static String get orderSchool => _t('Escuela', 'School');
  static String get orderPickup => _t('Punto de recogida', 'Pickup point');
  static String get orderDistance => _t('Distancia', 'Distance');

  // ── Reports ───────────────────────────────────────────────────────────────
  static String get reportTitle =>
      _t('Informes de entrega', 'Delivery Reports');
  static String get reportNew => _t('Nuevo informe', 'New report');
  static String get reportCondition =>
      _t('Estado de los alimentos', 'Food condition');
  static String get reportConditionGood => _t('Bueno', 'Good');
  static String get reportConditionFair => _t('Regular', 'Fair');
  static String get reportConditionPoor => _t('Malo', 'Poor');
  static String get reportNotes => _t('Notas', 'Notes');
  static String get reportPhotos => _t('Fotos', 'Photos');
  static String get reportAddPhoto => _t('Agregar foto', 'Add photo');
  static String get reportSubmit => _t('Enviar informe', 'Submit report');
  static String get reportSubmitted =>
      _t('Informe enviado', 'Report submitted');
  static String get reportPendingSync =>
      _t('Sincronización pendiente', 'Pending sync');
  static String get reportSynced => _t('Sincronizado', 'Synced');
  static String get reportNoReports => _t('Sin informes aún', 'No reports yet');
  static String get reportSchool => _t('Escuela', 'School');
  static String get reportDate => _t('Fecha', 'Date');
  static String get reportBy => _t('Enviado por', 'Submitted by');
  static String get reportViewPhotos => _t('Ver fotos', 'View photos');

  // ── Personnel ─────────────────────────────────────────────────────────────
  static String get personnelTitle => _t('Personal', 'Personnel');
  static String get personnelAdd => _t('Agregar personal', 'Add personnel');
  static String get personnelEmpty =>
      _t('Sin personal registrado aún', 'No personnel registered yet');
  static String get personnelDelete =>
      _t('Eliminar personal', 'Remove personnel');
  static String get personnelDeleteConfirm => _t(
    '¿Eliminar esta persona del sistema?',
    'Remove this person from the system?',
  );
  static String get personnelEdit => _t('Editar', 'Edit');
  static String get personnelAdminOnly => _t(
    'Solo los administradores pueden crear o eliminar usuarios.',
    'Only administrators can create or remove users.',
  );
  static String get personnelCreated =>
      _t('Usuario creado exitosamente', 'User created successfully');
  static String get personnelCannotDeleteSelf => _t(
    'No puedes eliminar tu propia cuenta',
    'You cannot remove your own account',
  );

  // ── Messages ──────────────────────────────────────────────────────────────
  static String get messagesTitle => _t('Mensajes', 'Messages');
  static String get messagesTypeHere =>
      _t('Escribe un mensaje…', 'Type a message…');
  static String get messagesSend => _t('Enviar', 'Send');
  static String get messagesEmpty => _t('Sin mensajes aún', 'No messages yet');

  // ── Settings / Profile ────────────────────────────────────────────────────
  static String get settingsTitle => _t('Configuración', 'Settings');
  static String get profileTitle => _t('Mi Perfil', 'My Profile');
  static String get profileEditPhoto => _t('Cambiar foto', 'Change photo');
  static String get profileLogout => _t('Cerrar sesión', 'Log out');
  static String get profileLogoutConfirm => _t(
    '¿Seguro que quieres cerrar sesión?',
    'Are you sure you want to log out?',
  );
  static String get profilePrivacy => _t('Privacidad', 'Privacy');
  static String get profileNotifications =>
      _t('Notificaciones', 'Notifications');
  static String get profilePhone => _t('Teléfono', 'Phone');
  static String get profileIdNumber => _t('Número de ID', 'ID Number');
  static String get profileInstitution => _t('Institución', 'Institution');
  static String get profileSyncStatus => _t('Estado sync', 'Sync status');
  static String get profileSynced => _t('Sincronizado', 'Synced');
  static String get profilePendingSync => _t('Sync pendiente', 'Pending sync');
  static String get profileVersion => _t('PAEGo v2.0.0', 'PAEGo v2.0.0');
  static String get settingsTheme => _t('Modo oscuro', 'Dark mode');
  static String get settingsLanguage => _t('Idioma', 'Language');
  static String get settingsSync => _t('Sincronizar datos', 'Sync data now');
  static String get settingsSyncing => _t('Sincronizando…', 'Syncing…');
  static String get settingsSyncDone =>
      _t('Datos sincronizados', 'All data synced');

  // ── Connectivity ──────────────────────────────────────────────────────────
  static String get syncOffline => _t(
    'Sin conexión — cambios guardados localmente',
    'Offline — changes saved locally',
  );
  static String get syncOnline =>
      _t('Conectado — sincronizando datos', 'Back online — syncing data');

  // ── Common ────────────────────────────────────────────────────────────────
  static String get cancel => _t('Cancelar', 'Cancel');
  static String get confirm => _t('Confirmar', 'Confirm');
  static String get save => _t('Guardar', 'Save');
  static String get update => _t('Actualizar', 'Update');
  static String get delete => _t('Eliminar', 'Delete');
  static String get edit => _t('Editar', 'Edit');
  static String get close => _t('Cerrar', 'Close');
  static String get retry => _t('Reintentar', 'Retry');
  static String get loading => _t('Cargando…', 'Loading…');
  static String get error => _t('Algo salió mal', 'Something went wrong');
  static String get required => _t('Campo obligatorio', 'Required field');
  static String get comingSoon => _t(' – próximamente', ' – coming soon');
  static String get pageNotFound =>
      _t('Página no encontrada', 'Page not found');
  static String get routeNotFound =>
      _t('Esta ruta no existe.', 'This route does not exist.');
  static String get yes => _t('Sí', 'Yes');
  static String get no => _t('No', 'No');
  static String get search => _t('Buscar', 'Search');
  static String get noResults => _t('Sin resultados', 'No results found');
  static String get viewAll => _t('Ver todo', 'View all');
  static String get unknown => _t('Desconocido', 'Unknown');
}
