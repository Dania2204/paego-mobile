import 'user_role.dart';

class AppUser {
  AppUser({
    this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.idNumber,
    required this.role,
    this.institution,
    this.photoPath,
    this.passwordHash,
    this.createdAt,
    this.syncedAt,
    this.isSynced = false,
    this.conductorId,
    this.institucionId,
    this.aceptoTratamientoDatos = true,
  });

  /// Perfil devuelto por la API de oPAEGo (`/api/auth/token/` o `/api/auth/yo/`).
  factory AppUser.fromPerfil(Map<String, dynamic> p) {
    final nombre = (p['nombre'] as String?)?.trim() ?? '';
    return AppUser(
      id: p['id'] as int,
      fullName: nombre.isNotEmpty ? nombre : (p['email'] as String? ?? ''),
      email: p['email'] as String? ?? '',
      phone: p['telefono'] as String? ?? '',
      idNumber: '',
      role: UserRoleX.fromBackend(p['rol'] as String?),
      conductorId: p['conductor_id'] as int?,
      institucionId: p['institucion_id'] as int?,
      aceptoTratamientoDatos: p['acepto_tratamiento_datos_en'] != null,
      isSynced: true,
    );
  }

  /// Sesión guardada en el teléfono (para abrir la app sin conexión).
  Map<String, dynamic> toSesion() => {
    'id': id,
    'nombre': fullName,
    'email': email,
    'telefono': phone,
    'rol': switch (role) {
      UserRole.admin || UserRole.superAdmin => 'ADMINISTRADOR',
      UserRole.rector => 'INSTITUCION',
      UserRole.driver => 'CONDUCTOR',
    },
    'conductor_id': conductorId,
    'institucion_id': institucionId,
    'acepto_tratamiento_datos_en': aceptoTratamientoDatos ? 'si' : null,
  };

  final int? id;
  final String fullName;
  final String email;
  final String phone;
  final String idNumber;
  final UserRole role;
  final String? institution;
  final String? photoPath;
  final String? passwordHash;
  final DateTime? createdAt;
  final DateTime? syncedAt;
  final bool isSynced;

  /// Id del conductor en el backend (solo rol conductor).
  final int? conductorId;

  /// Id de la institución en el backend (solo rol institución).
  final int? institucionId;

  /// RNF-11: aceptó la política de tratamiento de datos (Ley 1581).
  final bool aceptoTratamientoDatos;

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'id_number': idNumber,
    'role': role.name,
    'institution': institution,
    'photo_path': photoPath,
    'password_hash': passwordHash,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    'synced_at': syncedAt?.toIso8601String(),
    'is_synced': isSynced ? 1 : 0,
  };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    id: m['id'] as int?,
    fullName: m['full_name'] as String,
    email: m['email'] as String,
    phone: m['phone'] as String? ?? '',
    idNumber: m['id_number'] as String? ?? '',
    role: UserRoleX.fromString(m['role'] as String),
    institution: m['institution'] as String?,
    photoPath: m['photo_path'] as String?,
    passwordHash: m['password_hash'] as String?,
    createdAt: m['created_at'] != null
        ? DateTime.tryParse(m['created_at'] as String)
        : null,
    syncedAt: m['synced_at'] != null
        ? DateTime.tryParse(m['synced_at'] as String)
        : null,
    isSynced: (m['is_synced'] as int? ?? 0) == 1,
  );

  AppUser copyWith({
    int? id,
    String? fullName,
    String? email,
    String? phone,
    String? idNumber,
    UserRole? role,
    String? institution,
    String? photoPath,
    String? passwordHash,
    DateTime? createdAt,
    DateTime? syncedAt,
    bool? isSynced,
    bool? aceptoTratamientoDatos,
  }) =>
      AppUser(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        idNumber: idNumber ?? this.idNumber,
        role: role ?? this.role,
        institution: institution ?? this.institution,
        photoPath: photoPath ?? this.photoPath,
        passwordHash: passwordHash ?? this.passwordHash,
        createdAt: createdAt ?? this.createdAt,
        syncedAt: syncedAt ?? this.syncedAt,
        isSynced: isSynced ?? this.isSynced,
        conductorId: conductorId,
        institucionId: institucionId,
        aceptoTratamientoDatos:
            aceptoTratamientoDatos ?? this.aceptoTratamientoDatos,
      );
}
