import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'comparador.dart';
import 'extractor.dart';
import 'preprocesado.dart';

const _carpeta = 'assets/modelos';

ExtractorRostro crearExtractor() => (Platform.isAndroid || Platform.isIOS)
    ? ExtractorMovil()
    : const ExtractorNoDisponible();

/// Contrato del modelo, descrito en `assets/modelos/modelo.json` (el `.tflite`
/// no se versiona). Así se puede cambiar de modelo sin tocar el código.
class ConfigModelo {
  const ConfigModelo({
    this.archivo = 'mobilefacenet.tflite',
    this.nombre = 'mobilefacenet-tflite',
    this.minimo = -1,
    this.maximo = 1,
  });

  factory ConfigModelo.fromJson(Map<String, dynamic> j) {
    final rango = (j['rango'] as List?)?.cast<num>();
    return ConfigModelo(
      archivo: j['archivo'] as String? ?? 'mobilefacenet.tflite',
      nombre: j['nombre'] as String? ?? 'mobilefacenet-tflite',
      minimo: rango?.first.toDouble() ?? -1,
      maximo: rango?.last.toDouble() ?? 1,
    );
  }

  final String archivo;

  /// Versión del modelo que viaja al servidor con cada inscripción (≤ 40).
  final String nombre;

  /// Rango al que se llevan los píxeles.
  final double minimo;
  final double maximo;
}

class ExtractorMovil implements ExtractorRostro {
  Interpreter? _modelo;
  FaceDetector? _detector;
  ConfigModelo _config = const ConfigModelo();
  bool? _disponible;

  @override
  String get modelo => _config.nombre;

  @override
  Future<bool> disponible() async {
    final previo = _disponible;
    if (previo != null) return previo;
    try {
      try {
        _config = ConfigModelo.fromJson(
          (jsonDecode(await rootBundle.loadString('$_carpeta/modelo.json'))
                  as Map)
              .cast<String, dynamic>(),
        );
      } catch (_) {
        _config = const ConfigModelo();
      }
      _modelo = await Interpreter.fromAsset('$_carpeta/${_config.archivo}');
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableClassification: true,
          minFaceSize: 0.2,
        ),
      );
      return _disponible = true;
    } catch (_) {
      // El APK no trae el modelo: la app sigue con el registro manual.
      return _disponible = false;
    }
  }

  /// Corre el modelo sobre la cara y devuelve el vector (sin normalizar).
  List<double> _vector(img.Image cara) {
    final m = _modelo!;
    final forma = m.getInputTensor(0).shape;
    // [1, 3, L, L] (NCHW) o [1, L, L, 3] (NHWC).
    final canalesPrimero = forma[1] == 3;
    final tensor = tensorDeEntrada(
      cara,
      canalesPrimero ? forma[2] : forma[1],
      canalesPrimero: canalesPrimero,
      minimo: _config.minimo,
      maximo: _config.maximo,
    );
    final salida = m.getOutputTensor(0).shape; // [n, D]
    final resultado = List.generate(
      salida.first,
      (_) => List<double>.filled(salida.last, 0),
    );
    final entradas = m.getInputTensors().length;
    if (entradas == 1) {
      m.run(tensor, resultado);
    } else {
      // Modelos de verificación (img1, img2): la fila 0 depende solo de img1.
      m.runForMultipleInputs(List.filled(entradas, tensor), {0: resultado});
    }
    return resultado.first;
  }

  @override
  Future<MuestraRostro> analizar(String rutaFoto) async {
    if (!await disponible()) return const MuestraRostro();
    final archivo = File(rutaFoto);
    try {
      final caras = await _detector!.processImage(
        InputImage.fromFilePath(rutaFoto),
      );
      if (caras.length != 1) return MuestraRostro(caras: caras.length);
      final cara = caras.single;
      final ojos = [
        cara.leftEyeOpenProbability,
        cara.rightEyeOpenProbability,
      ].whereType<double>();
      final decodificada = img.decodeImage(await archivo.readAsBytes());
      if (decodificada == null) return const MuestraRostro(caras: 1);
      // ML Kit da la caja sobre la imagen ya rotada según su EXIF.
      final foto = img.bakeOrientation(decodificada);
      final recorte = recortarCara(foto, cara.boundingBox);
      return MuestraRostro(
        vector: normalizar(_vector(recorte)),
        caras: 1,
        giroY: cara.headEulerAngleY,
        ojosAbiertos: ojos.isEmpty
            ? null
            : ojos.reduce((a, b) => a < b ? a : b),
      );
    } finally {
      // Nunca se guardan fotos de los estudiantes (Ley 1581).
      try {
        await archivo.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> cerrar() async {
    _modelo?.close();
    await _detector?.close();
    _modelo = null;
    _detector = null;
    _disponible = null;
  }
}
