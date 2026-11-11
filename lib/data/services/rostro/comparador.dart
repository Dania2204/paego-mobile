import 'dart:math';

/// Comparación de plantillas faciales (vectores del modelo) en el teléfono.
///
/// El reconocimiento es 1:N dentro de un curso (~35 estudiantes): se busca la
/// plantilla más parecida y se exige que supere el umbral del servidor
/// (`umbral_similitud_facial`). El supervisor siempre confirma el resultado.

/// Normaliza a norma 1 (la similitud coseno queda como producto punto).
List<double> normalizar(List<double> v) {
  var suma = 0.0;
  for (final x in v) {
    suma += x * x;
  }
  final norma = sqrt(suma);
  if (norma == 0 || norma.isNaN) {
    throw ArgumentError('El vector del rostro es nulo.');
  }
  return [for (final x in v) x / norma];
}

double similitudCoseno(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError('Vectores de dimensión distinta.');
  }
  var punto = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    punto += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 0;
  return punto / (sqrt(na) * sqrt(nb));
}

class Coincidencia {
  const Coincidencia({
    required this.estudianteId,
    required this.similitud,
    required this.segunda,
  });

  final int estudianteId;

  /// Similitud con la mejor muestra del estudiante (0..1).
  final double similitud;

  /// Mejor similitud de cualquier OTRO estudiante (para ver si es ambigua).
  final double segunda;

  /// Dos estudiantes casi igual de parecidos: el supervisor debe revisar.
  bool ambigua([double margen = 0.05]) => similitud - segunda < margen;
}

/// Identifica el rostro [vector] entre las [plantillas] (estudiante → muestras).
/// Devuelve `null` si nadie alcanza el [umbral].
Coincidencia? identificar(
  List<double> vector,
  Map<int, List<List<double>>> plantillas, {
  required double umbral,
}) {
  int? mejorId;
  var mejor = -1.0;
  var segunda = -1.0;
  plantillas.forEach((id, muestras) {
    var propia = -1.0;
    for (final m in muestras) {
      if (m.length != vector.length) continue;
      propia = max(propia, similitudCoseno(vector, m));
    }
    if (propia > mejor) {
      segunda = mejor;
      mejor = propia;
      mejorId = id;
    } else if (propia > segunda) {
      segunda = propia;
    }
  });
  if (mejorId == null || mejor < umbral) return null;
  return Coincidencia(
    estudianteId: mejorId!,
    similitud: mejor,
    segunda: max(segunda, 0),
  );
}

/// Revisa que las muestras de una inscripción sean de la misma persona:
/// cada una debe parecerse a las demás (si no, se pide repetir la toma).
bool muestrasConsistentes(List<List<double>> muestras, {double minimo = 0.5}) {
  for (var i = 0; i < muestras.length; i++) {
    for (var j = i + 1; j < muestras.length; j++) {
      if (similitudCoseno(muestras[i], muestras[j]) < minimo) return false;
    }
  }
  return true;
}
