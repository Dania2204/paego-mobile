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

/// Imagen → tensor [1][lado][lado][3] normalizado a [-1, 1] ((p - 127.5) / 128),
/// la normalización con que se entrenó MobileFaceNet.
List<List<List<List<double>>>> tensorDeEntrada(img.Image cara, int lado) {
  final r = img.copyResize(
    cara,
    width: lado,
    height: lado,
    interpolation: img.Interpolation.linear,
  );
  return [
    [
      for (var y = 0; y < lado; y++)
        [
          for (var x = 0; x < lado; x++)
            () {
              final p = r.getPixel(x, y);
              return [
                (p.r - 127.5) / 128,
                (p.g - 127.5) / 128,
                (p.b - 127.5) / 128,
              ];
            }(),
        ],
    ],
  ];
}
