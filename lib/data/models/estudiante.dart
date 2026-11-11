/// Estudiante beneficiario del PAE (identidad mínima del SIMAT, Ley 1581).
///
/// Viene de `GET /api/estudiantes/` con su estado del día; la app le aplica
/// encima las operaciones que aún no llegan al servidor (cola RF-38).
class Estudiante {
  const Estudiante({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.grado,
    required this.grupo,
    required this.curso,
    this.autorizacionVigente = false,
    this.rostroInscrito = false,
    this.entregaFecha,
    this.entregaMetodo,
    this.entregaHora,
    this.entregaPendiente = false,
  });

  factory Estudiante.fromJson(Map<String, dynamic> j) {
    final entrega = (j['entrega_del_dia'] as Map?)?.cast<String, dynamic>();
    return Estudiante(
      id: j['id'] as int,
      nombres: j['nombres'] as String? ?? '',
      apellidos: j['apellidos'] as String? ?? '',
      tipoDocumento: j['tipo_documento'] as String? ?? '',
      numeroDocumento: j['numero_documento'] as String? ?? '',
      grado: '${j['grado'] ?? ''}',
      grupo: '${j['grupo'] ?? ''}',
      curso: j['curso'] as String? ?? '${j['grado']} ${j['grupo']}',
      autorizacionVigente: j['autorizacion_vigente'] == true,
      rostroInscrito: j['rostro_inscrito'] == true,
      entregaFecha: entrega?['fecha'] as String?,
      entregaMetodo: entrega?['metodo'] as String?,
      entregaHora: entrega?['ocurrido_en'] == null
          ? null
          : DateTime.tryParse(entrega!['ocurrido_en'] as String)?.toLocal(),
    );
  }

  final int id;
  final String nombres;
  final String apellidos;
  final String tipoDocumento;
  final String numeroDocumento;
  final String grado;
  final String grupo;

  /// Etiqueta del curso, p. ej. "7° B".
  final String curso;
  final bool autorizacionVigente;
  final bool rostroInscrito;

  /// Día (AAAA-MM-DD) de la última entrega conocida.
  final String? entregaFecha;

  /// FACIAL | MANUAL
  final String? entregaMetodo;
  final DateTime? entregaHora;

  /// La entrega está en el teléfono y aún no llega al servidor.
  final bool entregaPendiente;

  String get nombreCompleto => '$nombres $apellidos'.trim();
  String get documento => '$tipoDocumento $numeroDocumento'.trim();

  /// ¿Recibió el PAE hoy? (la caché puede ser de un día anterior).
  bool get recibioHoy => entregaFecha == fechaDeHoy();

  Estudiante copyWith({
    bool? autorizacionVigente,
    bool? rostroInscrito,
    String? entregaFecha,
    String? entregaMetodo,
    DateTime? entregaHora,
    bool? entregaPendiente,
  }) => Estudiante(
    id: id,
    nombres: nombres,
    apellidos: apellidos,
    tipoDocumento: tipoDocumento,
    numeroDocumento: numeroDocumento,
    grado: grado,
    grupo: grupo,
    curso: curso,
    autorizacionVigente: autorizacionVigente ?? this.autorizacionVigente,
    rostroInscrito: rostroInscrito ?? this.rostroInscrito,
    entregaFecha: entregaFecha ?? this.entregaFecha,
    entregaMetodo: entregaMetodo ?? this.entregaMetodo,
    entregaHora: entregaHora ?? this.entregaHora,
    entregaPendiente: entregaPendiente ?? this.entregaPendiente,
  );
}

/// Avance de un curso en el día.
class CursoResumen {
  const CursoResumen({
    required this.grado,
    required this.grupo,
    required this.curso,
    required this.activos,
    required this.recibieron,
    required this.conRostro,
  });

  final String grado;
  final String grupo;
  final String curso;
  final int activos;
  final int recibieron;
  final int conRostro;

  double get avance => activos == 0 ? 0 : recibieron / activos;

  /// Agrupa los estudiantes por curso, ordenados por grado y grupo.
  static List<CursoResumen> de(Iterable<Estudiante> estudiantes) {
    final grupos = <String, List<Estudiante>>{};
    for (final e in estudiantes) {
      grupos.putIfAbsent('${e.grado}|${e.grupo}', () => []).add(e);
    }
    final lista = [
      for (final l in grupos.values)
        CursoResumen(
          grado: l.first.grado,
          grupo: l.first.grupo,
          curso: l.first.curso,
          activos: l.length,
          recibieron: l.where((e) => e.recibioHoy).length,
          conRostro: l.where((e) => e.rostroInscrito).length,
        ),
    ];
    lista.sort((a, b) {
      final g = ordenGrado(a.grado).compareTo(ordenGrado(b.grado));
      return g != 0 ? g : a.grupo.compareTo(b.grupo);
    });
    return lista;
  }
}

/// Orden de los grados del SIMAT: preescolar (-2..0) antes de 1..11; los
/// códigos no numéricos (ciclos de adultos) al final.
int ordenGrado(String grado) => int.tryParse(grado) ?? 1000;

String fechaDeHoy([DateTime? ahora]) {
  final d = ahora ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
