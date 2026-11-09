## Qué cambia

<!-- Resumen corto del cambio y por qué. -->

## Requerimientos relacionados

<!-- RF-xx / RNF-xx del documento del proyecto (repo oPAEGo/docs). -->

## Cómo se probó

- [ ] `flutter analyze --no-fatal-infos` sin errores ni warnings
- [ ] `flutter test` en verde
- [ ] Probado en un teléfono o emulador contra la API (indique la URL)

## Checklist

- [ ] Las acciones nuevas pasan por la cola sin conexión (`SyncService`), no llaman la API directo
- [ ] Sin `.env`, claves ni datos personales en el commit
- [ ] Textos nuevos con `S.text(...)` en español e inglés
