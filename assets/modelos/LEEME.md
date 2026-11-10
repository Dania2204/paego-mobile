# Modelo de reconocimiento facial

La app busca aquí `mobilefacenet.tflite` (entrada `[1, 112, 112, 3]` normalizada a [-1, 1],
salida `[1, 192]`). Si el archivo no está, el supervisor trabaja solo con registro manual:
la app compila y funciona igual.

El modelo **no se versiona** (`.gitignore`): antes de incluirlo, verificar su procedencia y
licencia. MobileFaceNet (código Apache-2.0) suele distribuirse con pesos entrenados en MS1M,
un conjunto de uso académico: sirve para la tesis, pero en operación real hay que reentrenarlo
con datos con licencia o licenciar un modelo comercial.

Tras cambiar el modelo, recalibrar `UMBRAL_SIMILITUD_FACIAL` en el servidor con pruebas reales.
