import 'dart:math';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

/// Recorta la cara con un margen y la deja cuadrada (lo que espera el modelo).
img.Image recortarCara(img.Image foto, Rect caja, {double margen = 0.2}) {
  final lado = max(caja.width, caja.height) * (1 + margen);
  final cx = caja.center.dx, cy = caja.center.dy;
  var x = (cx - lado / 2).round();
  var y = (cy - lado / 2).round();
  var l = lado.round();
  x = x.clamp(0, max(0, foto.width - 1));
  y = y.clamp(0, max(0, foto.height - 1));
  l = min(l, min(foto.width - x, foto.height - y));
  return img.copyCrop(foto, x: x, y: y, width: l, height: l);
}

/// Imagen → tensor de entrada del modelo, con los píxeles llevados al rango
/// [minimo, maximo] (MobileFaceNet de Qualcomm: [0, 1]; otros: [-1, 1]).
/// [canalesPrimero]: `[1][3][lado][lado]` (NCHW, exportado de PyTorch);
/// si no, `[1][lado][lado][3]` (NHWC, TensorFlow).
List<List<List<List<double>>>> tensorDeEntrada(
  img.Image cara,
  int lado, {
  bool canalesPrimero = false,
  double minimo = -1,
  double maximo = 1,
}) {
  final r = img.copyResize(
    cara,
    width: lado,
    height: lado,
    interpolation: img.Interpolation.linear,
  );
  final escala = (maximo - minimo) / 255;
  double canal(int x, int y, int c) {
    final p = r.getPixel(x, y);
    final v = c == 0 ? p.r : (c == 1 ? p.g : p.b);
    return minimo + v * escala;
  }

  if (canalesPrimero) {
    return [
      [
        for (var c = 0; c < 3; c++)
          [
            for (var y = 0; y < lado; y++)
              [for (var x = 0; x < lado; x++) canal(x, y, c)],
          ],
      ],
    ];
  }
  return [
    [
      for (var y = 0; y < lado; y++)
        [
          for (var x = 0; x < lado; x++)
            [for (var c = 0; c < 3; c++) canal(x, y, c)],
        ],
    ],
  ];
}
