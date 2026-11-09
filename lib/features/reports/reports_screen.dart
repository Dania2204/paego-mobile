import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/models/envio.dart';
import '../../data/models/user_model.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/envio_repository.dart';
import '../../data/sync/sync_service.dart';
import '../envios/envio_widgets.dart';

/// Informes: todo lo que el usuario registró en la app (salidas, llegadas,
/// novedades, recepciones) y si ya llegó a la plataforma web.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Operacion> _operaciones = [];
  bool _loading = true;
  StreamSubscription<List<Operacion>>? _sub;

  @override
  void initState() {
    super.initState();
    SyncService.instance.estado.addListener(_load);
    _sub = SyncService.instance.onAplicadas.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    SyncService.instance.estado.removeListener(_load);
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final ops = await SyncService.instance.historial();
    if (!mounted) return;
    setState(() {
      _operaciones = ops;
      _loading = false;
    });
  }

  Future<void> _nuevo() async {
    final candidatos = EnvioRepository.instance.envios.value
        .where((e) => e.estado != EstadoEnvio.cancelado)
        .where((e) => e.estado.esActivo || e.estado == EstadoEnvio.entregado)
        .toList();
    if (candidatos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.text(
              'informe.sin_envios',
              'No hay envíos para reportar.',
              'There are no deliveries to report on.',
            ),
          ),
        ),
      );
      return;
    }
    final envio = await showModalBottomSheet<Envio>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                S.text(
                  'informe.elegir_envio',
                  '¿Sobre qué envío?',
                  'Which delivery?',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            for (final e in candidatos)
              EnvioTile(envio: e, onTap: () => Navigator.pop(ctx, e)),
          ],
        ),
      ),
    );
    if (envio == null || !mounted) return;
    if (widget.user.role.canConfirmReception && envio.puedeConfirmar) {
      await mostrarConfirmarRecepcion(context, envio);
    } else {
      await mostrarNuevaNovedad(context, envio);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = widget.user.role.canSubmitReport;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: S.reportTitle,
            subtitle: S.text(
              'informe.subtitulo',
              'Lo que registró en la app y su estado en la plataforma',
              'What you recorded and its status on the platform',
            ),
            height: 110,
            actions: [
              IconButton(
                icon: const Icon(Icons.sync_rounded, color: Colors.white),
                tooltip: S.text(
                  'informe.sincronizar',
                  'Sincronizar ahora',
                  'Sync now',
                ),
                onPressed: () async {
                  await SyncService.instance.sincronizar();
                  await _load();
                },
              ),
              if (canSubmit)
                IconButton(
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _nuevo,
                ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: PaeColors.primary),
                  )
                : _operaciones.isEmpty
                ? _Vacio(
                    texto: canSubmit
                        ? S.text(
                            'informe.vacio',
                            'Aún no ha registrado novedades ni entregas. Use + para reportar.',
                            'No issues or deliveries recorded yet. Use + to report.',
                          )
                        : S.text(
                            'informe.vacio_admin',
                            'Las novedades se gestionan en la plataforma web.',
                            'Issues are managed on the web platform.',
                          ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await SyncService.instance.sincronizar();
                      await _load();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _operaciones.length,
                      itemBuilder: (_, i) => _OperacionCard(
                        op: _operaciones[i],
                        onDescartar: () async {
                          await SyncService.instance.descartar(
                            _operaciones[i].uuid,
                          );
                          await _load();
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 56,
              color: PaeColors.inactive,
            ),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PaeColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperacionCard extends StatelessWidget {
  const _OperacionCard({required this.op, required this.onDescartar});
  final Operacion op;
  final VoidCallback onDescartar;

  static const _iconos = {
    'envio.salida': Icons.play_arrow_rounded,
    'envio.llegada': Icons.flag_rounded,
    'envio.novedad': Icons.report_gmailerrorred_rounded,
    'envio.confirmar': Icons.fact_check_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (etiqueta, color) = op.pendiente
        ? (
            S.text('op.pendiente', 'Pendiente de envío', 'Pending upload'),
            PaeColors.warning,
          )
        : op.rechazada
        ? (S.text('op.rechazada', 'Rechazada', 'Rejected'), PaeColors.error)
        : (
            S.text('op.enviada', 'En la plataforma', 'On the platform'),
            PaeColors.success,
          );
    final descripcion = op.datos['descripcion'] as String?;
    final tieneFoto =
        op.datos['foto'] != null ||
        (op.datos['novedad'] is Map &&
            (op.datos['novedad'] as Map)['foto'] != null);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? PaeColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : PaeColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconos[op.tipo] ?? Icons.sync_rounded,
                color: PaeColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  op.resumen.isEmpty ? op.tipo : op.resumen,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(label: etiqueta, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatoFecha(op.ocurridoEn) + (tieneFoto ? ' · 📷' : ''),
            style: const TextStyle(
              color: PaeColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (descripcion != null && descripcion.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(descripcion),
          ],
          if (op.rechazada) ...[
            const SizedBox(height: 8),
            Text(
              op.motivoRechazo,
              style: const TextStyle(color: PaeColors.error, fontSize: 13),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onDescartar,
                child: Text(S.text('op.descartar', 'Descartar', 'Dismiss')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
