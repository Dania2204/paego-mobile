import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/models/estudiante.dart';
import '../../data/remote/api_client.dart';
import '../../data/repositories/estudiantes_repository.dart';
import '../../data/services/rostro/comparador.dart';
import '../../data/services/rostro/extractor.dart';
import '../../data/sync/sync_service.dart';
import 'captura_rostro_screen.dart';

EstudiantesRepository get _repo => EstudiantesRepository.instance;

/// ¿Se puede usar el reconocimiento facial en este teléfono? (modelo + cámara
/// + el servidor con biometría configurada). Si no, todo queda en manual.
Future<bool> facialDisponible() async =>
    _repo.config.value.disponible && await extractorRostro.disponible();

void _avisar(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(texto),
      backgroundColor: error ? PaeColors.error : null,
    ),
  );
}

String _hora(DateTime? d) => d == null ? '' : DateFormat.Hm().format(d);

// ═══════════════════════════════════════════════════════════════════════════
// Cursos (pestaña principal del supervisor)
// ═══════════════════════════════════════════════════════════════════════════

class SupervisorCursosScreen extends StatefulWidget {
  const SupervisorCursosScreen({super.key});

  @override
  State<SupervisorCursosScreen> createState() => _SupervisorCursosScreenState();
}

class _SupervisorCursosScreenState extends State<SupervisorCursosScreen> {
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _descargar(silencioso: true);
  }

  Future<void> _descargar({bool silencioso = false}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _repo.descargar();
    } on SinConexionException {
      _error = S.text(
        'sup.sin_red',
        'Sin conexión: se muestran los datos guardados en el teléfono.',
        'Offline: showing the data saved on the phone.',
      );
    } on ApiException catch (e) {
      _error = e.mensaje;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientHeader(
        title: S.text('sup.titulo', 'Entrega del PAE', 'School meal delivery'),
        subtitle: DateFormat.yMMMMEEEEd(
          S.isSpanish ? 'es' : 'en',
        ).format(DateTime.now()),
        actions: [
          IconButton(
            tooltip: S.text('sup.actualizar', 'Actualizar', 'Refresh'),
            onPressed: _cargando ? null : _descargar,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Estudiante>>(
        valueListenable: _repo.estudiantes,
        builder: (context, estudiantes, _) {
          final cursos = CursoResumen.de(estudiantes);
          final recibieron = estudiantes.where((e) => e.recibioHoy).length;
          return RefreshIndicator(
            onRefresh: _descargar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_cargando) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: PaeColors.warning),
                    ),
                  ),
                if (estudiantes.isEmpty && !_cargando)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Text(
                      S.text(
                        'sup.vacio',
                        'No hay estudiantes descargados. Conéctese a internet '
                            'y actualice. Si sigue vacío, el administrador debe '
                            'importar los estudiantes del SIMAT.',
                        'No students downloaded. Connect and refresh. If it '
                            'stays empty, the administrator must import them.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else ...[
                  _Resumen(recibieron: recibieron, activos: estudiantes.length),
                  const SizedBox(height: 16),
                  SectionHeader(
                    title: S.text('sup.cursos', 'Cursos', 'Classes'),
                  ),
                  for (final c in cursos) _TarjetaCurso(curso: c),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.recibieron, required this.activos});

  final int recibieron;
  final int activos;

  @override
  Widget build(BuildContext context) {
    final avance = activos == 0 ? 0.0 : recibieron / activos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.text('sup.hoy', 'Recibieron hoy', 'Received today'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '$recibieron de $activos',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: avance, minHeight: 6),
          ],
        ),
      ),
    );
  }
}

class _TarjetaCurso extends StatelessWidget {
  const _TarjetaCurso({required this.curso});

  final CursoResumen curso;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          curso.curso,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            LinearProgressIndicator(value: curso.avance, minHeight: 4),
            const SizedBox(height: 4),
            Text(
              '${curso.recibieron} de ${curso.activos} recibieron · '
              '${curso.conRostro} con rostro',
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CursoScreen(grado: curso.grado, grupo: curso.grupo),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Un curso: lista del día, reconocimiento y registro manual
// ═══════════════════════════════════════════════════════════════════════════

class CursoScreen extends StatefulWidget {
  const CursoScreen({super.key, required this.grado, required this.grupo});

  final String grado;
  final String grupo;

  @override
  State<CursoScreen> createState() => _CursoScreenState();
}

class _CursoScreenState extends State<CursoScreen> {
  final _busqueda = TextEditingController();
  bool _facial = false;

  @override
  void initState() {
    super.initState();
    facialDisponible().then((v) {
      if (mounted) setState(() => _facial = v);
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  List<Estudiante> _filtrar(List<Estudiante> lista) {
    final q = _busqueda.text.trim().toLowerCase();
    if (q.isEmpty) return lista;
    return lista
        .where(
          (e) =>
              e.nombreCompleto.toLowerCase().contains(q) ||
              e.numeroDocumento.startsWith(q),
        )
        .toList();
  }

  Future<void> _reconocer() async {
    final plantillas = await _repo.plantillasDelCurso(
      widget.grado,
      widget.grupo,
    );
    if (!mounted) return;
    if (plantillas.isEmpty) {
      _avisar(
        context,
        S.text(
          'sup.sin_plantillas',
          'Nadie de este curso tiene el rostro inscrito todavía.',
          'Nobody in this class has an enrolled face yet.',
        ),
      );
      return;
    }
    final umbral = _repo.config.value.umbral;
    var seguir = true;
    while (seguir) {
      if (!mounted) return;
      final muestras = await Navigator.push<List<MuestraRostro>>(
        context,
        MaterialPageRoute(
          builder: (_) => CapturaRostroScreen(
            titulo: S.text('sup.reconocer', 'Reconocer', 'Recognise'),
            pasos: pasosReconocimiento(),
          ),
        ),
      );
      if (muestras == null || !mounted) return;
      final c = identificar(muestras.last.vector!, plantillas, umbral: umbral);
      seguir = await _resultado(c);
    }
  }

  /// Muestra el resultado y devuelve si se sigue con el siguiente estudiante.
  Future<bool> _resultado(Coincidencia? c) async {
    final e = c == null ? null : _repo.porId(c.estudianteId);
    if (c == null || e == null) {
      final r = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            S.text('sup.no_reconocido', 'No se reconoció', 'Not recognised'),
          ),
          content: Text(
            S.text(
              'sup.no_reconocido_texto',
              'Intente de nuevo con mejor luz o busque al estudiante en la '
                  'lista y registre la entrega sin cámara.',
              'Try again with better light, or find the student in the list '
                  'and record the delivery without the camera.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.text('sup.terminar', 'Terminar', 'Finish')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.text('sup.reintentar', 'Reintentar', 'Retry')),
            ),
          ],
        ),
      );
      return r ?? false;
    }
    if (e.recibioHoy) {
      final r = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(e.nombreCompleto),
          content: Text(
            '${S.text('sup.ya_recibio', 'Ya recibió el PAE hoy', 'Already received today')}'
            ' (${_hora(e.entregaHora)}).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.text('sup.terminar', 'Terminar', 'Finish')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.text('sup.siguiente', 'Siguiente', 'Next')),
            ),
          ],
        ),
      );
      return r ?? false;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(e.nombreCompleto),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${e.curso} · ${e.documento}'),
            const SizedBox(height: 8),
            Text(
              '${S.text('sup.similitud', 'Similitud', 'Similarity')}: '
              '${(c.similitud * 100).toStringAsFixed(0)} %',
            ),
            if (c.ambigua()) ...[
              const SizedBox(height: 8),
              Text(
                S.text(
                  'sup.ambigua',
                  'Se parece también a otro estudiante: verifique antes de confirmar.',
                  'Also resembles another student: check before confirming.',
                ),
                style: const TextStyle(color: PaeColors.warning),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.text('sup.no_es', 'No es', 'Not them')),
          ),
          FilledButton(
            key: const Key('confirmar_entrega'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              S.text('sup.confirmar', 'Confirmar entrega', 'Confirm'),
            ),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _repo.entregar(e, metodo: 'FACIAL', similitud: c.similitud);
      if (mounted) {
        _avisar(context, '✓ ${e.nombreCompleto}');
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${S.text('sup.curso', 'Curso', 'Class')} '
          '${_repo.delCurso(widget.grado, widget.grupo).firstOrNull?.curso ?? ''}',
        ),
      ),
      floatingActionButton: _facial
          ? FloatingActionButton.extended(
              key: const Key('reconocer'),
              onPressed: _reconocer,
              icon: const Icon(Icons.face_rounded),
              label: Text(S.text('sup.reconocer', 'Reconocer', 'Recognise')),
            )
          : null,
      body: ValueListenableBuilder<List<Estudiante>>(
        valueListenable: _repo.estudiantes,
        builder: (context, _, _) {
          final lista = _repo.delCurso(widget.grado, widget.grupo);
          final recibieron = lista.where((e) => e.recibioHoy).length;
          final filtrada = _filtrar(lista);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _busqueda,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: S.text(
                      'sup.buscar',
                      'Buscar por nombre o documento',
                      'Search by name or ID',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('$recibieron de ${lista.length} recibieron'),
                    const Spacer(),
                    if (!_facial)
                      Text(
                        S.text(
                          'sup.solo_manual',
                          'Registro manual',
                          'Manual only',
                        ),
                        style: const TextStyle(color: PaeColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: filtrada.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _FilaEstudiante(
                    estudiante: filtrada[i],
                    onTap: () => _acciones(filtrada[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _acciones(Estudiante e) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                e.nombreCompleto,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${e.curso} · ${e.documento}'),
            ),
            if (!e.recibioHoy)
              ListTile(
                key: const Key('accion_manual'),
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: Text(
                  S.text(
                    'sup.manual',
                    'Registrar entrega sin cámara',
                    'Record delivery without camera',
                  ),
                ),
                onTap: () => Navigator.pop(ctx, 'manual'),
              ),
            if (!e.autorizacionVigente)
              ListTile(
                key: const Key('accion_autorizar'),
                leading: const Icon(Icons.assignment_turned_in_outlined),
                title: Text(
                  S.text(
                    'sup.autorizar',
                    'Registrar autorización del acudiente',
                    'Record guardian consent',
                  ),
                ),
                onTap: () => Navigator.pop(ctx, 'inscribir'),
              ),
            if (e.autorizacionVigente && _facial)
              ListTile(
                leading: const Icon(Icons.face_retouching_natural_rounded),
                title: Text(
                  e.rostroInscrito
                      ? S.text(
                          'sup.reinscribir',
                          'Volver a inscribir el rostro',
                          'Re-enrol face',
                        )
                      : S.text(
                          'sup.inscribir',
                          'Inscribir rostro',
                          'Enrol face',
                        ),
                ),
                onTap: () => Navigator.pop(ctx, 'inscribir'),
              ),
            if (e.autorizacionVigente)
              ListTile(
                leading: const Icon(
                  Icons.block_rounded,
                  color: PaeColors.error,
                ),
                title: Text(
                  S.text(
                    'sup.revocar',
                    'Revocar autorización (borra el rostro)',
                    'Revoke consent (deletes the face)',
                  ),
                ),
                onTap: () => Navigator.pop(ctx, 'revocar'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || accion == null) return;
    switch (accion) {
      case 'manual':
        await _entregaManual(e);
      case 'inscribir':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InscribirScreen(estudiante: e, facial: _facial),
          ),
        );
      case 'revocar':
        await _revocar(e);
    }
  }

  Future<void> _entregaManual(Estudiante e) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoMotivo(),
    );
    if (motivo == null || !mounted) return;
    try {
      await _repo.entregar(e, metodo: 'MANUAL', motivo: motivo);
      if (mounted) _avisar(context, '✓ ${e.nombreCompleto}');
    } on StateError catch (err) {
      if (mounted) _avisar(context, err.message, error: true);
    }
  }

  Future<void> _revocar(Estudiante e) async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          S.text('sup.revocar_t', 'Revocar autorización', 'Revoke consent'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.text(
                'sup.revocar_texto',
                'Se borrarán las plantillas faciales del estudiante. Podrá '
                    'seguir recibiendo el PAE con registro manual.',
                'The face templates will be deleted. Deliveries can still be '
                    'recorded manually.',
              ),
            ),
            TextField(
              controller: motivo,
              decoration: InputDecoration(
                labelText: S.text('sup.motivo', 'Motivo', 'Reason'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.text('comun.cancelar', 'Cancelar', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PaeColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.text('sup.revocar_si', 'Revocar', 'Revoke')),
          ),
        ],
      ),
    );
    if (ok == true) await _repo.revocar(e, motivo: motivo.text.trim());
    motivo.dispose();
  }
}

class _FilaEstudiante extends StatelessWidget {
  const _FilaEstudiante({required this.estudiante, required this.onTap});

  final Estudiante estudiante;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = estudiante;
    return ListTile(
      onTap: onTap,
      title: Text('${e.apellidos}, ${e.nombres}'),
      subtitle: Row(
        children: [
          Text(e.documento),
          const SizedBox(width: 8),
          Icon(
            e.autorizacionVigente
                ? Icons.assignment_turned_in_rounded
                : Icons.assignment_outlined,
            size: 14,
            color: e.autorizacionVigente
                ? PaeColors.primary
                : PaeColors.inactive,
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.face_rounded,
            size: 14,
            color: e.rostroInscrito ? PaeColors.primary : PaeColors.inactive,
          ),
        ],
      ),
      trailing: e.recibioHoy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.entregaPendiente)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      size: 16,
                      color: PaeColors.warning,
                    ),
                  ),
                StatusBadge(
                  label:
                      '${S.text('sup.recibio', 'Recibió', 'Received')} '
                      '${_hora(e.entregaHora)}',
                  color: PaeColors.statusDelivered,
                ),
              ],
            )
          : StatusBadge(
              label: S.text('sup.pendiente', 'Pendiente', 'Pending'),
              color: PaeColors.statusAssigned,
            ),
    );
  }
}

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo();

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  static final _motivos = [
    S.text(
      'sup.m_sin_autorizacion',
      'Sin autorización biométrica',
      'No biometric consent',
    ),
    S.text(
      'sup.m_no_reconocido',
      'El reconocimiento falló',
      'Recognition failed',
    ),
    S.text(
      'sup.m_sin_camara',
      'Sin cámara o poca luz',
      'No camera or poor light',
    ),
  ];
  String? _elegido;
  final _otro = TextEditingController();

  @override
  void dispose() {
    _otro.dispose();
    super.dispose();
  }

  String get _motivo =>
      _elegido == '_otro' ? _otro.text.trim() : (_elegido ?? '');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        S.text('sup.manual_t', 'Entrega sin cámara', 'Delivery without camera'),
      ),
      content: RadioGroup<String>(
        groupValue: _elegido,
        onChanged: (v) => setState(() => _elegido = v),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in _motivos)
              RadioListTile<String>(value: m, title: Text(m)),
            RadioListTile<String>(
              value: '_otro',
              title: TextField(
                controller: _otro,
                onTap: () => setState(() => _elegido = '_otro'),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: S.text('sup.otro', 'Otro motivo', 'Other reason'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.text('comun.cancelar', 'Cancelar', 'Cancel')),
        ),
        FilledButton(
          key: const Key('guardar_manual'),
          onPressed: _motivo.isEmpty
              ? null
              : () => Navigator.pop(context, _motivo),
          child: Text(S.text('sup.registrar', 'Registrar', 'Record')),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Autorización del acudiente + inscripción del rostro
// ═══════════════════════════════════════════════════════════════════════════

class InscribirScreen extends StatefulWidget {
  const InscribirScreen({
    super.key,
    required this.estudiante,
    required this.facial,
  });

  final Estudiante estudiante;
  final bool facial;

  @override
  State<InscribirScreen> createState() => _InscribirScreenState();
}

class _InscribirScreenState extends State<InscribirScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _documento = TextEditingController();
  final _parentesco = TextEditingController();
  bool _confirmo = false;
  bool _guardando = false;
  late bool _autorizado = widget.estudiante.autorizacionVigente;

  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    _parentesco.dispose();
    super.dispose();
  }

  Future<void> _guardarAutorizacion() async {
    if (!_form.currentState!.validate() || !_confirmo) return;
    setState(() => _guardando = true);
    await _repo.autorizar(
      widget.estudiante,
      acudienteNombre: _nombre.text,
      acudienteDocumento: _documento.text,
      parentesco: _parentesco.text,
    );
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _autorizado = true;
    });
    if (!widget.facial) Navigator.pop(context);
  }

  Future<void> _tomarFotos() async {
    final config = _repo.config.value;
    final muestras = await Navigator.push<List<MuestraRostro>>(
      context,
      MaterialPageRoute(
        builder: (_) => CapturaRostroScreen(
          titulo: widget.estudiante.nombreCompleto,
          pasos: pasosInscripcion(config.muestrasMax.clamp(3, 5)),
        ),
      ),
    );
    if (muestras == null || !mounted) return;
    final vectores = [for (final m in muestras) m.vector!];
    if (!muestrasConsistentes(vectores)) {
      _avisar(
        context,
        S.text(
          'sup.inconsistente',
          'Las fotos no parecen de la misma persona. Repita la inscripción.',
          'The photos do not look like the same person. Try again.',
        ),
        error: true,
      );
      return;
    }
    await _repo.inscribir(
      widget.estudiante,
      vectores: vectores,
      modelo: extractorRostro.modelo,
    );
    if (!mounted) return;
    _avisar(
      context,
      S.text('sup.inscrito', 'Rostro inscrito.', 'Face enrolled.'),
    );
    Navigator.pop(context);
  }

  String? _requerido(String? v) => (v == null || v.trim().isEmpty)
      ? S.text('comun.requerido', 'Obligatorio', 'Required')
      : null;

  @override
  Widget build(BuildContext context) {
    final e = widget.estudiante;
    return Scaffold(
      appBar: AppBar(title: Text(e.nombreCompleto)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${e.curso} · ${e.documento}'),
          const SizedBox(height: 16),
          if (!_autorizado)
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.text(
                      'sup.aut_titulo',
                      'Autorización del acudiente',
                      'Guardian consent',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.text(
                      'sup.aut_texto',
                      'Los datos biométricos de menores son sensibles (Ley 1581, '
                          'art. 5 y 7). Antes de tomar fotos, el acudiente debe '
                          'firmar el formato de autorización del colegio. Si no '
                          'autoriza, el estudiante recibe el PAE igual, con '
                          'registro manual.',
                      'Biometric data of minors is sensitive (Law 1581). The '
                          'guardian must sign the consent form first. Without '
                          'consent, deliveries are recorded manually.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('acudiente_nombre'),
                    controller: _nombre,
                    validator: _requerido,
                    decoration: InputDecoration(
                      labelText: S.text(
                        'sup.acudiente',
                        'Nombre del acudiente',
                        'Guardian name',
                      ),
                    ),
                  ),
                  TextFormField(
                    key: const Key('acudiente_documento'),
                    controller: _documento,
                    validator: _requerido,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: S.text(
                        'sup.acudiente_doc',
                        'Documento del acudiente',
                        'Guardian ID',
                      ),
                    ),
                  ),
                  TextFormField(
                    key: const Key('parentesco'),
                    controller: _parentesco,
                    validator: _requerido,
                    decoration: InputDecoration(
                      labelText: S.text(
                        'sup.parentesco',
                        'Parentesco (madre, padre, abuela…)',
                        'Relationship',
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    key: const Key('confirmo'),
                    contentPadding: EdgeInsets.zero,
                    value: _confirmo,
                    onChanged: (v) => setState(() => _confirmo = v ?? false),
                    title: Text(
                      S.text(
                        'sup.confirmo',
                        'Tengo el formato firmado por el acudiente.',
                        'I have the form signed by the guardian.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('guardar_autorizacion'),
                    onPressed: _guardando || !_confirmo
                        ? null
                        : _guardarAutorizacion,
                    child: Text(
                      S.text(
                        'sup.guardar_aut',
                        'Guardar autorización',
                        'Save consent',
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: PaeColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.text(
                      'sup.aut_ok',
                      'Autorización del acudiente registrada.',
                      'Guardian consent recorded.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.facial) ...[
              Text(
                S.text(
                  'sup.fotos_texto',
                  'Se tomarán varias fotos guiadas. No se guardan: el teléfono '
                      'solo conserva una plantilla numérica cifrada.',
                  'Several guided photos will be taken. They are not stored: '
                      'only an encrypted numeric template is kept.',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _tomarFotos,
                icon: const Icon(Icons.camera_front_rounded),
                label: Text(
                  S.text('sup.tomar_fotos', 'Tomar fotos', 'Take photos'),
                ),
              ),
            ] else
              Text(
                S.text(
                  'sup.sin_facial',
                  'Este teléfono no tiene el reconocimiento facial: la '
                      'entrega se registra de forma manual.',
                  'Face recognition is not available on this phone: record '
                      'deliveries manually.',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Historial (lo registrado desde este teléfono y su estado)
// ═══════════════════════════════════════════════════════════════════════════

class HistorialSupervisorScreen extends StatefulWidget {
  const HistorialSupervisorScreen({super.key});

  @override
  State<HistorialSupervisorScreen> createState() =>
      _HistorialSupervisorScreenState();
}

class _HistorialSupervisorScreenState extends State<HistorialSupervisorScreen> {
  late Future<List<Operacion>> _ops = _cargar();

  Future<List<Operacion>> _cargar() =>
      SyncService.instance.historial(limite: 300, prefijo: 'estudiante.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientHeader(
        title: S.text('sup.historial', 'Historial', 'History'),
        subtitle: S.text(
          'sup.historial_sub',
          'Lo que registró y su estado en la plataforma',
          'What you recorded and its status',
        ),
      ),
      body: ValueListenableBuilder<EstadoSync>(
        valueListenable: SyncService.instance.estado,
        builder: (context, _, _) {
          _ops = _cargar();
          return FutureBuilder<List<Operacion>>(
            future: _ops,
            builder: (context, snap) {
              final ops = snap.data ?? const [];
              if (snap.connectionState != ConnectionState.done && ops.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (ops.isEmpty) {
                return Center(
                  child: Text(
                    S.text(
                      'sup.historial_vacio',
                      'Aún no ha registrado nada.',
                      'Nothing recorded yet.',
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: ops.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final op = ops[i];
                  final (icono, color) = op.pendiente
                      ? (Icons.cloud_upload_outlined, PaeColors.warning)
                      : op.rechazada
                      ? (Icons.error_outline_rounded, PaeColors.error)
                      : (Icons.cloud_done_outlined, PaeColors.success);
                  return ListTile(
                    leading: Icon(icono, color: color),
                    title: Text(op.resumen),
                    subtitle: Text(
                      [
                        DateFormat('d MMM HH:mm', 'es').format(op.ocurridoEn),
                        if (op.rechazada) op.motivoRechazo,
                      ].join(' · '),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Institución (rector): solo lectura, en línea
// ═══════════════════════════════════════════════════════════════════════════

class EstudiantesHoyScreen extends StatefulWidget {
  const EstudiantesHoyScreen({super.key});

  @override
  State<EstudiantesHoyScreen> createState() => _EstudiantesHoyScreenState();
}

class _EstudiantesHoyScreenState extends State<EstudiantesHoyScreen> {
  late Future<Map<String, dynamic>> _datos = _cargar();

  Future<Map<String, dynamic>> _cargar() async =>
      ((await ApiClient.instance.get('/estudiantes/cursos/')) as Map)
          .cast<String, dynamic>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientHeader(
        title: S.text('rector.estudiantes', 'Estudiantes', 'Students'),
        subtitle: S.text(
          'rector.estudiantes_sub',
          'Quién recibió el PAE hoy',
          'Who received the school meal today',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _datos = _cargar());
          await _datos;
        },
        child: FutureBuilder<Map<String, dynamic>>(
          future: _datos,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      snap.error is SinConexionException
                          ? S.text(
                              'rector.sin_red',
                              'Sin conexión. Deslice para reintentar.',
                              'Offline. Pull to retry.',
                            )
                          : snap.error is ApiException
                          ? (snap.error as ApiException).mensaje
                          : snap.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cob = (snap.data!['cobertura'] as Map)
                .cast<String, dynamic>();
            final cursos = (snap.data!['cursos'] as List).cast<Map>();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Resumen(
                  recibieron: cob['recibieron'] as int,
                  activos: cob['activos'] as int,
                ),
                const SizedBox(height: 12),
                for (final c in cursos)
                  Card(
                    child: ListTile(
                      title: Text('${c['curso']}'),
                      subtitle: LinearProgressIndicator(
                        value: (c['activos'] as int) == 0
                            ? 0
                            : (c['recibieron'] as int) / (c['activos'] as int),
                      ),
                      trailing: Text('${c['recibieron']} / ${c['activos']}'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
