import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../data/services/rostro/comparador.dart';
import '../../data/services/rostro/extractor.dart';

/// Por qué una foto no sirve; con [reiniciar] se vuelve al primer paso.
class Rechazo {
  const Rechazo(this.mensaje, {this.reiniciar = false});

  final String mensaje;
  final bool reiniciar;
}

/// Un paso de la toma: la instrucción y cómo validar la foto.
class PasoCaptura {
  const PasoCaptura(this.instruccion, this.validar);

  final String instruccion;

  /// Devuelve el rechazo (para repetir) o null si la foto sirve.
  final Rechazo? Function(MuestraRostro m, List<MuestraRostro> previas) validar;
}

const _giroMinimo = 15.0;
const _frenteMaximo = 12.0;

Rechazo? _deFrente(MuestraRostro m, List<MuestraRostro> _) {
  final y = m.giroY ?? 0;
  if (y.abs() > _frenteMaximo) {
    return Rechazo(
      S.text(
        'rostro.mirar_frente',
        'Pida que mire de frente a la cámara.',
        'Ask the student to look straight at the camera.',
      ),
    );
  }
  final ojos = m.ojosAbiertos;
  if (ojos != null && ojos < 0.3) {
    return Rechazo(
      S.text(
        'rostro.ojos',
        'Tiene los ojos cerrados. Repita la foto.',
        'Eyes are closed. Take the photo again.',
      ),
    );
  }
  return null;
}

Rechazo? _girado(MuestraRostro m, List<MuestraRostro> previas) {
  final y = m.giroY ?? 0;
  if (y.abs() < _giroMinimo) {
    return Rechazo(
      S.text(
        'rostro.girar',
        'Pida que gire un poco más la cabeza.',
        'Ask the student to turn their head a bit more.',
      ),
    );
  }
  // Si ya giró hacia un lado, ahora debe ser hacia el otro.
  for (final p in previas) {
    final py = p.giroY ?? 0;
    if (py.abs() >= _giroMinimo && py.sign == y.sign) {
      return Rechazo(
        S.text(
          'rostro.otro_lado',
          'Ahora hacia el otro lado.',
          'Now towards the other side.',
        ),
      );
    }
  }
  return null;
}

/// Pasos para inscribir: de frente y girando a ambos lados. Una foto plana
/// no cambia de perspectiva, así que esto también sirve de prueba de vida.
List<PasoCaptura> pasosInscripcion(int muestras) {
  final pasos = <PasoCaptura>[
    PasoCaptura(
      S.text('rostro.p_frente', 'Mire de frente', 'Look straight ahead'),
      _deFrente,
    ),
    PasoCaptura(
      S.text(
        'rostro.p_lado1',
        'Gire un poco la cabeza hacia un lado',
        'Turn your head slightly to one side',
      ),
      _girado,
    ),
    PasoCaptura(
      S.text(
        'rostro.p_lado2',
        'Ahora gire un poco hacia el otro lado',
        'Now turn slightly to the other side',
      ),
      _girado,
    ),
  ];
  while (pasos.length < muestras) {
    pasos.add(
      PasoCaptura(
        S.text(
          'rostro.p_frente2',
          'De nuevo de frente',
          'Straight ahead again',
        ),
        _deFrente,
      ),
    );
  }
  return pasos.take(max(3, muestras)).toList();
}

/// Pasos para reconocer en la entrega: girar (prueba de vida) y de frente.
/// La foto de frente es la que se compara; las dos deben ser la misma persona.
List<PasoCaptura> pasosReconocimiento() => [
  PasoCaptura(
    S.text(
      'rostro.r_girar',
      'Que gire un poco la cabeza',
      'Turn the head slightly',
    ),
    _girado,
  ),
  PasoCaptura(
    S.text('rostro.r_frente', 'Ahora de frente', 'Now straight ahead'),
    (m, previas) {
      final problema = _deFrente(m, previas);
      if (problema != null) return problema;
      if (previas.isNotEmpty &&
          similitudCoseno(m.vector!, previas.last.vector!) < 0.5) {
        return Rechazo(
          S.text(
            'rostro.otra_persona',
            'Las dos fotos no parecen de la misma persona. Empiece de nuevo.',
            'The two photos do not look like the same person. Start again.',
          ),
          reiniciar: true,
        );
      }
      return null;
    },
  ),
];

/// Cámara frontal guiada por pasos. Devuelve las muestras válidas (sin fotos:
/// cada foto se analiza en el teléfono y se borra) o null si se cancela.
class CapturaRostroScreen extends StatefulWidget {
  const CapturaRostroScreen({
    super.key,
    required this.titulo,
    required this.pasos,
  });

  final String titulo;
  final List<PasoCaptura> pasos;

  @override
  State<CapturaRostroScreen> createState() => _CapturaRostroScreenState();
}

class _CapturaRostroScreenState extends State<CapturaRostroScreen> {
  CameraController? _camara;
  String? _error;
  bool _analizando = false;
  String? _aviso;
  final _muestras = <MuestraRostro>[];

  @override
  void initState() {
    super.initState();
    _abrirCamara();
  }

  Future<void> _abrirCamara() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) throw CameraException('sin_camara', null);
      final frontal = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => camaras.first,
      );
      final c = CameraController(
        frontal,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _camara = c);
    } on CameraException catch (e) {
      setState(
        () => _error = e.code == 'CameraAccessDenied'
            ? S.text(
                'rostro.sin_permiso',
                'La app no tiene permiso para usar la cámara.',
                'The app has no camera permission.',
              )
            : S.text(
                'rostro.sin_camara',
                'No se pudo abrir la cámara.',
                'Could not open the camera.',
              ),
      );
    }
  }

  @override
  void dispose() {
    _camara?.dispose();
    super.dispose();
  }

  Future<void> _tomar() async {
    final c = _camara;
    if (c == null || _analizando) return;
    setState(() {
      _analizando = true;
      _aviso = null;
    });
    try {
      final foto = await c.takePicture();
      final m = await extractorRostro.analizar(foto.path);
      final paso = widget.pasos[_muestras.length];
      final rechazo = m.problema != null
          ? Rechazo(m.problema!)
          : paso.validar(m, _muestras);
      if (!mounted) return;
      if (rechazo != null) {
        if (rechazo.reiniciar) _muestras.clear();
        setState(() => _aviso = rechazo.mensaje);
        return;
      }
      _muestras.add(m);
      if (_muestras.length == widget.pasos.length) {
        Navigator.pop(context, List<MuestraRostro>.of(_muestras));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _aviso = S.text(
            'rostro.fallo',
            'No se pudo tomar la foto. Intente de nuevo.',
            'Could not take the photo. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _camara;
    final paso = _muestras.length < widget.pasos.length
        ? widget.pasos[_muestras.length]
        : null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.titulo),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : c == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(child: CameraPreview(c)),
                      // Guía: óvalo donde debe quedar la cara.
                      IgnorePointer(
                        child: Container(
                          width: 230,
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 3,
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.elliptical(115, 150),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    children: [
                      Text(
                        '${_muestras.length + 1} / ${widget.pasos.length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paso?.instruccion ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_aviso != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _aviso!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: PaeColors.warning),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: FilledButton(
                          key: const Key('tomar_foto'),
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: Colors.white,
                            foregroundColor: PaeColors.primary,
                          ),
                          onPressed: _analizando ? null : _tomar,
                          child: _analizando
                              ? const CircularProgressIndicator()
                              : const Icon(Icons.camera_alt_rounded, size: 30),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
