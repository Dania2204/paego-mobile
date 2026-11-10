import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'comparador.dart';
import 'extractor.dart';
import 'preprocesado.dart';

const rutaModelo = 'assets/modelos/mobilefacenet.tflite';

ExtractorRostro crearExtractor() => (Platform.isAndroid || Platform.isIOS)
    ? ExtractorMovil()
    : const ExtractorNoDisponible();

class ExtractorMovil implements ExtractorRostro {
  Interpreter? _modelo;
  FaceDetector? _detector;
  bool? _disponible;

  @override
  String get modelo => 'mobilefacenet-tflite';

  @override
  Future<bool> disponible() async {
    final previo = _disponible;
    if (previo != null) return previo;
    try {
      await rootBundle.load(rutaModelo);
      _modelo = await Interpreter.fromAsset(rutaModelo);
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
      final entrada = _modelo!.getInputTensor(0).shape; // [1, 112, 112, 3]
      final salida = _modelo!.getOutputTensor(0).shape; // [1, 192]
      final resultado = [List<double>.filled(salida.last, 0)];
      _modelo!.run(tensorDeEntrada(recorte, entrada[1]), resultado);
      return MuestraRostro(
        vector: normalizar(resultado.first),
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
