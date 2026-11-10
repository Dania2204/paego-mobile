# Modelo de reconocimiento facial

`modelo.json` describe el modelo que usa la app (archivo, rango de los píxeles, versión que se
envía al servidor). La forma de la entrada (NCHW/NHWC), el tamaño y la dimensión del vector se
leen del propio `.tflite`. Si el archivo no está, el supervisor trabaja solo con registro manual:
la app compila y funciona igual.

## Modelo de la demo: MobileFaceNet de Qualcomm AI Hub (v0.66.0)

- Descarga: <https://huggingface.co/qualcomm/MobileFaceNet> →
  `mobile_facenet-tflite-float.zip` (de `qaihub-public-assets`, URL exacta en `modelo.json`).
  Copiar `mobile_facenet.tflite` (3,99 MB) a esta carpeta.
- SHA-256: `2046ab776fba2ec7e420767ffe7eb74a7402a8412d3d7ea8b9f4ca8420e5f3d7`.
- Entradas `img1`, `img2` `[1, 3, 112, 112]` en [0, 1] (RGB); salida `[2, 128]`. La app pasa la
  misma cara en ambas entradas y usa la fila 0 (depende solo de `img1`, verificado).
- **No se versiona** (`.gitignore`): la tarjeta del modelo es Apache-2.0, pero los pesos se
  entrenaron con MS-Celeb-1M, un conjunto de uso académico. Sirve para la tesis; en operación real
  hay que reentrenar con datos con licencia o licenciar un modelo comercial.

## Umbral

Con modelos ArcFace la similitud coseno de una misma persona suele quedar entre 0,5 y 0,8, así que
el `UMBRAL_SIMILITUD_FACIAL` del servidor (0,80 por defecto) debe **calibrarse** con fotos reales
del piloto (con consentimiento) antes de usarlo: si es muy alto, casi nadie se reconoce y todo
termina en registro manual; si es muy bajo, aumentan las confusiones (el supervisor confirma).
