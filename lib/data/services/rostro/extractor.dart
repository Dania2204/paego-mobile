import 'extractor_stub.dart'
    if (dart.library.ffi) 'extractor_movil.dart'
    as implementacion;

/// Resultado de analizar una foto: la cara detectada y su plantilla.
class MuestraRostro {
  const MuestraRostro({
    this.vector,
    this.caras = 0,
    this.giroY,
    this.ojosAbiertos,
  });

  /// Plantilla facial (norma 1). Null si no hubo exactamente una cara.
  final List<double>? vector;

  /// Caras detectadas en la foto.
  final int caras;

  /// Giro de la cabeza a izquierda/derecha en grados (ML Kit).
  final double? giroY;

  /// Probabilidad mínima de ojos abiertos (0..1), si se pudo estimar.
  final double? ojosAbiertos;

  /// Mensaje para el supervisor si la foto no sirve.
  String? get problema {
    if (caras == 0) return 'No se ve ninguna cara. Acerque el teléfono.';
    if (caras > 1) return 'Hay más de una cara en la foto.';
    if (vector == null) return 'No se pudo analizar la cara. Repita la foto.';
    return null;
  }
}

/// Convierte una foto en una plantilla facial, en el teléfono y sin red:
/// ML Kit detecta la cara y un modelo TFLite (MobileFaceNet) genera el vector.
/// Nunca se guardan fotos: la foto temporal se borra tras analizarla.
abstract class ExtractorRostro {
  /// Versión del modelo (viaja al servidor con cada inscripción).
  String get modelo;

  /// Hay cámara, ML Kit y el archivo del modelo en este dispositivo.
  Future<bool> disponible();

  Future<MuestraRostro> analizar(String rutaFoto);

  Future<void> cerrar();
}

/// Sin modelo (web, escritorio o APK sin el `.tflite`): solo registro manual.
class ExtractorNoDisponible implements ExtractorRostro {
  const ExtractorNoDisponible();

  @override
  String get modelo => '';

  @override
  Future<bool> disponible() async => false;

  @override
  Future<MuestraRostro> analizar(String rutaFoto) async =>
      const MuestraRostro();

  @override
  Future<void> cerrar() async {}
}

ExtractorRostro? _instancia;

/// Extractor de la plataforma (se puede reemplazar en pruebas).
ExtractorRostro get extractorRostro =>
    _instancia ??= implementacion.crearExtractor();

set extractorRostro(ExtractorRostro e) => _instancia = e;
