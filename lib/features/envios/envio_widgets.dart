import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/models/envio.dart';
import '../../data/models/user_model.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/envio_repository.dart';
import '../../data/services/rastreo_service.dart';

final _hora = DateFormat('d MMM · h:mm a', 'es');

String formatoFecha(DateTime? f) {
  if (f == null) return '—';
  try {
    return _hora.format(f);
  } catch (_) {
    return DateFormat('d/MM HH:mm').format(f);
  }
}

void _aviso(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(texto),
      backgroundColor: error ? PaeColors.error : null,
    ),
  );
}

// ── Tarjeta de envío ─────────────────────────────────────────────────────────

class EnvioTile extends StatelessWidget {
  const EnvioTile({super.key, required this.envio, this.onTap, this.margin});

  final Envio envio;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:
            margin ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? PaeColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : PaeColors.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: envio.estado.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                color: envio.estado.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    envio.codigo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFamily: PaeTypography.fontBody,
                    ),
                  ),
                  Text(
                    envio.institucion.nombreCompleto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PaeColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    formatoFecha(envio.programadoPara),
                    style: const TextStyle(
                      color: PaeColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(
                  label: envio.estado.label,
                  color: envio.estado.color,
                ),
                if (envio.estaRetrasado && envio.estado.esActivo) ...[
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: S.text('envio.retrasado', 'Retrasado', 'Late'),
                    color: PaeColors.error,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detalle del envío con sus acciones ───────────────────────────────────────

Future<void> mostrarDetalleEnvio(
  BuildContext context,
  Envio envio,
  AppUser user,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => ValueListenableBuilder<List<Envio>>(
        valueListenable: EnvioRepository.instance.envios,
        builder: (ctx, _, _) {
          final actual = EnvioRepository.instance.porId(envio.id) ?? envio;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PaeColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      actual.codigo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        fontFamily: PaeTypography.fontDisplay,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label: actual.estado.label,
                    color: actual.estado.color,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                actual.institucion.nombreCompleto,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (actual.institucion.direccion.isNotEmpty)
                Text(
                  actual.institucion.direccion,
                  style: const TextStyle(
                    color: PaeColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 12),
              _Dato(
                S.text('envio.programado', 'Programado', 'Scheduled'),
                formatoFecha(actual.programadoPara),
              ),
              _Dato(
                S.text('envio.conductor', 'Conductor', 'Driver'),
                [
                  actual.conductorNombre,
                  actual.vehiculoPlaca,
                ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              ),
              if (actual.salidaEn != null)
                _Dato(
                  S.text('envio.salida', 'Salida', 'Departure'),
                  formatoFecha(actual.salidaEn),
                ),
              if (actual.llegadaEn != null)
                _Dato(
                  S.text('envio.llegada', 'Llegada', 'Arrival'),
                  formatoFecha(actual.llegadaEn),
                ),
              if (actual.entregadoEn != null)
                _Dato(
                  S.text('envio.entregado_en', 'Entregado', 'Delivered'),
                  formatoFecha(actual.entregadoEn),
                ),
              if (actual.observaciones.isNotEmpty)
                _Dato(
                  S.text('envio.observaciones', 'Observaciones', 'Notes'),
                  actual.observaciones,
                ),

              // El conductor muestra este código a la institución (RF-27).
              if (user.role.canDriveRoute &&
                  actual.codigoVerificacion != null &&
                  actual.estado == EstadoEnvio.enTransito) ...[
                const SizedBox(height: 12),
                CodigoVerificacion(codigo: actual.codigoVerificacion!),
              ],

              const SizedBox(height: 16),
              Text(
                S.text('envio.alimentos', 'Alimentos', 'Food items'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              for (final item in actual.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.producto)),
                      Text(
                        '${ItemEnvio.formatear(item.cantidad)} ${item.unidadNombre.toLowerCase()}'
                        '${item.cantidadRecibida != null ? '  (recibido ${ItemEnvio.formatear(item.cantidadRecibida!)})' : ''}',
                        style: const TextStyle(color: PaeColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              ...accionesEnvio(ctx, actual, user, cerrarAlTerminar: true),
            ],
          );
        },
      ),
    ),
  );
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    if (valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              etiqueta,
              style: const TextStyle(
                color: PaeColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class CodigoVerificacion extends StatelessWidget {
  const CodigoVerificacion({super.key, required this.codigo});
  final String codigo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaeColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaeColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            S.text(
              'envio.codigo_para_institucion',
              'Código para la institución',
              'Code for the school',
            ),
            style: const TextStyle(
              color: PaeColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            codigo,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: PaeColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botones según el rol y el estado del envío.
List<Widget> accionesEnvio(
  BuildContext context,
  Envio envio,
  AppUser user, {
  bool cerrarAlTerminar = false,
}) {
  void cerrar() {
    if (cerrarAlTerminar && Navigator.of(context).canPop())
      Navigator.of(context).pop();
  }

  final botones = <Widget>[];
  if (user.role.canDriveRoute) {
    if (envio.puedeSalir) {
      botones.add(
        GradientButton(
          label: S.text(
            'envio.registrar_salida',
            'Registrar salida',
            'Start delivery',
          ),
          icon: Icons.play_arrow_rounded,
          onPressed: () async {
            if (await registrarSalida(context, envio)) cerrar();
          },
        ),
      );
    }
    if (envio.puedeLlegar) {
      botones.add(
        GradientButton(
          label: S.text(
            'envio.registrar_llegada',
            'Registrar llegada',
            'Record arrival',
          ),
          icon: Icons.flag_rounded,
          onPressed: () async {
            if (await registrarLlegada(context, envio)) cerrar();
          },
        ),
      );
    }
  }
  if (user.role.canConfirmReception && envio.puedeConfirmar) {
    botones.add(
      GradientButton(
        label: S.text(
          'envio.confirmar_recepcion',
          'Confirmar recepción',
          'Confirm reception',
        ),
        icon: Icons.fact_check_rounded,
        onPressed: () async {
          final ok = await mostrarConfirmarRecepcion(context, envio);
          if (ok == true) cerrar();
        },
      ),
    );
  }
  if (user.role.canSubmitReport && envio.estado != EstadoEnvio.cancelado) {
    botones.add(
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        icon: const Icon(Icons.report_gmailerrorred_rounded),
        label: Text(
          S.text(
            'envio.reportar_novedad',
            'Reportar novedad',
            'Report an issue',
          ),
        ),
        onPressed: () async {
          final ok = await mostrarNuevaNovedad(context, envio);
          if (ok == true) cerrar();
        },
      ),
    );
  }
  return [
    for (final b in botones)
      Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
  ];
}

// ── Acciones del conductor ───────────────────────────────────────────────────

Future<bool> registrarSalida(BuildContext context, Envio envio) async {
  final pos = RastreoService.instance.posicion.value;
  if (pos == null) {
    _aviso(
      context,
      S.text(
        'gps.sin_posicion',
        'Esperando la señal del GPS…',
        'Waiting for GPS signal…',
      ),
      error: true,
    );
    await RastreoService.instance.reintentar();
    return false;
  }
  final confirma = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        S.text('envio.registrar_salida', 'Registrar salida', 'Start delivery'),
      ),
      content: Text(
        S
            .text(
              'envio.confirmar_salida',
              '¿Sale ahora hacia {inst}? Su recorrido se enviará a la plataforma.',
              'Leave now for {inst}? Your route will be sent to the platform.',
            )
            .replaceAll('{inst}', envio.institucion.nombre),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(S.yes),
        ),
      ],
    ),
  );
  if (confirma != true) return false;
  await EnvioRepository.instance.registrarSalida(
    envio,
    lat: pos.latitude,
    lng: pos.longitude,
  );
  if (context.mounted) {
    _aviso(
      context,
      S.text(
        'envio.salida_ok',
        'Salida registrada. Buen viaje.',
        'Departure recorded.',
      ),
    );
  }
  return true;
}

Future<bool> registrarLlegada(BuildContext context, Envio envio) async {
  final pos = RastreoService.instance.posicion.value;
  if (pos == null) {
    _aviso(
      context,
      S.text(
        'gps.sin_posicion',
        'Esperando la señal del GPS…',
        'Waiting for GPS signal…',
      ),
      error: true,
    );
    return false;
  }
  await EnvioRepository.instance.registrarLlegada(
    envio,
    lat: pos.latitude,
    lng: pos.longitude,
  );
  if (context.mounted) {
    _aviso(
      context,
      S.text(
        'envio.llegada_ok',
        'Llegada registrada. Muestre el código a la institución.',
        'Arrival recorded. Show the code to the school.',
      ),
    );
  }
  return true;
}

// ── Foto (base64 para la cola sin conexión) ──────────────────────────────────

class FotoTomada {
  FotoTomada(this.bytes, this.dataUrl);
  final Uint8List bytes;
  final String dataUrl;
}

Future<FotoTomada?> tomarFoto(BuildContext context) async {
  final fuente = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: Text(S.text('foto.camara', 'Tomar foto', 'Take photo')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: Text(
              S.text(
                'foto.galeria',
                'Elegir de la galería',
                'Choose from gallery',
              ),
            ),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (fuente == null) return null;
  try {
    final archivo = await ImagePicker().pickImage(
      source: fuente,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (archivo == null) return null;
    final bytes = await archivo.readAsBytes();
    final tipo = (archivo.mimeType ?? 'image/jpeg').contains('png')
        ? 'png'
        : 'jpeg';
    return FotoTomada(bytes, 'data:image/$tipo;base64,${base64Encode(bytes)}');
  } catch (_) {
    if (context.mounted) {
      _aviso(
        context,
        S.text(
          'foto.error',
          'No se pudo obtener la foto.',
          'Could not get the photo.',
        ),
        error: true,
      );
    }
    return null;
  }
}

class _SelectorFoto extends StatelessWidget {
  const _SelectorFoto({required this.foto, required this.onCambiar});
  final FotoTomada? foto;
  final ValueChanged<FotoTomada?> onCambiar;

  @override
  Widget build(BuildContext context) {
    if (foto == null) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.add_a_photo_rounded),
        label: Text(
          S.text(
            'foto.agregar',
            'Agregar foto (opcional)',
            'Add photo (optional)',
          ),
        ),
        onPressed: () async => onCambiar(await tomarFoto(context)),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            foto!.bytes,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton.filled(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => onCambiar(null),
          ),
        ),
      ],
    );
  }
}

Widget _asa() => Center(
  child: Container(
    width: 40,
    height: 4,
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: PaeColors.divider,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

Widget _titulo(String texto) => Text(
  texto,
  style: const TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 18,
    fontFamily: PaeTypography.fontDisplay,
  ),
);

// ── Novedad (RF-23 conductor / RF-28 institución) ────────────────────────────

Future<bool?> mostrarNuevaNovedad(BuildContext context, Envio envio) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _NovedadSheet(envio: envio),
  );
}

class _NovedadSheet extends StatefulWidget {
  const _NovedadSheet({required this.envio});
  final Envio envio;

  @override
  State<_NovedadSheet> createState() => _NovedadSheetState();
}

class _NovedadSheetState extends State<_NovedadSheet> {
  final _form = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  TipoNovedad _tipo = TipoNovedad.retraso;
  FotoTomada? _foto;
  bool _guardando = false;

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final pos = RastreoService.instance.posicion.value;
    await EnvioRepository.instance.reportarNovedad(
      widget.envio,
      tipo: _tipo,
      descripcion: _descripcion.text.trim(),
      fotoBase64: _foto?.dataUrl,
      lat: pos?.latitude,
      lng: pos?.longitude,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
    _aviso(
      context,
      S.text('novedad.ok', 'Novedad registrada.', 'Issue reported.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _asa(),
              _titulo(
                S.text(
                  'envio.reportar_novedad',
                  'Reportar novedad',
                  'Report an issue',
                ),
              ),
              Text(
                '${widget.envio.codigo} · ${widget.envio.institucion.nombre}',
                style: const TextStyle(color: PaeColors.textSecondary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TipoNovedad>(
                value: _tipo,
                decoration: InputDecoration(
                  labelText: S.text('novedad.tipo', 'Tipo', 'Type'),
                ),
                items: [
                  for (final t in TipoNovedad.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (t) => setState(() => _tipo = t ?? _tipo),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcion,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: S.text(
                    'novedad.descripcion',
                    'Descripción',
                    'Description',
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? S.text(
                        'novedad.describa',
                        'Describa la novedad.',
                        'Describe the issue.',
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _SelectorFoto(
                foto: _foto,
                onCambiar: (f) => setState(() => _foto = f),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: S.text('novedad.enviar', 'Enviar novedad', 'Send issue'),
                icon: Icons.send_rounded,
                isLoading: _guardando,
                onPressed: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Confirmar recepción (RF-25 a RF-28, institución) ─────────────────────────

Future<bool?> mostrarConfirmarRecepcion(BuildContext context, Envio envio) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ConfirmarRecepcionSheet(envio: envio),
  );
}

class _ConfirmarRecepcionSheet extends StatefulWidget {
  const _ConfirmarRecepcionSheet({required this.envio});
  final Envio envio;

  @override
  State<_ConfirmarRecepcionSheet> createState() =>
      _ConfirmarRecepcionSheetState();
}

class _ConfirmarRecepcionSheetState extends State<_ConfirmarRecepcionSheet> {
  final _form = GlobalKey<FormState>();
  late final Map<int, TextEditingController> _cantidades = {
    for (final i in widget.envio.items)
      i.id: TextEditingController(text: ItemEnvio.formatear(i.cantidad)),
  };
  final _nombre = TextEditingController();
  final _cargo = TextEditingController();
  final _codigo = TextEditingController();
  final _novedad = TextEditingController();
  TipoNovedad _tipoNovedad = TipoNovedad.faltante;
  FotoTomada? _foto;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in _cantidades.values) {
      c.dispose();
    }
    _nombre.dispose();
    _cargo.dispose();
    _codigo.dispose();
    _novedad.dispose();
    super.dispose();
  }

  bool get _hayDiferencias => widget.envio.items.any((i) {
    final v = double.tryParse(_cantidades[i.id]!.text.replaceAll(',', '.'));
    return v != null && v != i.cantidad;
  });

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final pos = RastreoService.instance.posicion.value;
    await EnvioRepository.instance.confirmarRecepcion(
      widget.envio,
      recibidos: {
        for (final e in _cantidades.entries)
          e.key: double.parse(e.value.text.replaceAll(',', '.')),
      },
      recibidoPorNombre: _nombre.text.trim(),
      recibidoPorCargo: _cargo.text.trim(),
      codigoVerificacion: _codigo.text.trim(),
      fotoBase64: _foto?.dataUrl,
      lat: pos?.latitude,
      lng: pos?.longitude,
      tipoNovedad: _novedad.text.trim().isEmpty ? null : _tipoNovedad,
      descripcionNovedad: _novedad.text,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
    _aviso(
      context,
      S.text(
        'recepcion.ok',
        'Recepción registrada. Se enviará a la plataforma.',
        'Reception recorded. It will be sent to the platform.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requerido = S.text('campo.requerido', 'Obligatorio', 'Required');
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _asa(),
              _titulo(
                S.text(
                  'envio.confirmar_recepcion',
                  'Confirmar recepción',
                  'Confirm reception',
                ),
              ),
              Text(
                '${widget.envio.codigo} · ${widget.envio.conductorNombre}',
                style: const TextStyle(color: PaeColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                S.text(
                  'recepcion.cantidades',
                  'Cantidades recibidas',
                  'Received quantities',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final item in widget.envio.items)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.producto}\n${S.text('recepcion.enviado', 'Enviado', 'Sent')}: '
                          '${ItemEnvio.formatear(item.cantidad)} ${item.unidadNombre.toLowerCase()}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _cantidades[item.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.end,
                          validator: (v) {
                            final n = double.tryParse(
                              (v ?? '').replaceAll(',', '.'),
                            );
                            return (n == null || n < 0) ? '≥ 0' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codigo,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: S.text(
                    'recepcion.codigo',
                    'Código que muestra el conductor',
                    'Code shown by the driver',
                  ),
                ),
                validator: (v) => (v == null || v.trim().length != 6)
                    ? S.text(
                        'recepcion.codigo_6',
                        'Digite los 6 dígitos.',
                        'Enter the 6 digits.',
                      )
                    : null,
              ),
              TextFormField(
                controller: _nombre,
                decoration: InputDecoration(
                  labelText: S.text(
                    'recepcion.recibe',
                    'Quién recibe',
                    'Received by',
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? requerido : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cargo,
                decoration: InputDecoration(
                  labelText: S.text(
                    'recepcion.cargo',
                    'Cargo (opcional)',
                    'Position (optional)',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_hayDiferencias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    S.text(
                      'recepcion.diferencias',
                      'Hay diferencias con lo enviado: el envío quedará con novedad.',
                      'Quantities differ: the delivery will be marked with an issue.',
                    ),
                    style: const TextStyle(
                      color: PaeColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              DropdownButtonFormField<TipoNovedad>(
                value: _tipoNovedad,
                decoration: InputDecoration(
                  labelText: S.text(
                    'recepcion.tipo_novedad',
                    'Tipo de novedad (si hay)',
                    'Issue type (if any)',
                  ),
                ),
                items: [
                  for (final t in TipoNovedad.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (t) =>
                    setState(() => _tipoNovedad = t ?? _tipoNovedad),
              ),
              TextFormField(
                controller: _novedad,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: S.text(
                    'recepcion.novedad',
                    'Novedad en la recepción (opcional)',
                    'Reception issue (optional)',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SelectorFoto(
                foto: _foto,
                onCambiar: (f) => setState(() => _foto = f),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: S.text(
                  'envio.confirmar_recepcion',
                  'Confirmar recepción',
                  'Confirm reception',
                ),
                icon: Icons.check_circle_rounded,
                isLoading: _guardando,
                onPressed: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
