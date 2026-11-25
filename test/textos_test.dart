import 'package:flutter_test/flutter_test.dart';
import 'package:opaego/core/l10n/app_strings.dart';

void main() {
  setUpAll(() => S.guardarTextosNuevos = false);
  tearDown(() => S.setLocale('es'));

  String pendientes(int n) => S.cantidad(
    n,
    'prueba.pendientes',
    esUno: '1 cambio guardado',
    es: '{n} cambios guardados',
    enUno: '1 change saved',
    en: '{n} changes saved',
  );

  test('las cantidades usan singular con 1 y plural con las demás', () {
    expect(pendientes(1), '1 cambio guardado');
    expect(pendientes(3), '3 cambios guardados');
    expect(pendientes(0), '0 cambios guardados');
    S.setLocale('en');
    expect(pendientes(1), '1 change saved');
    expect(pendientes(2), '2 changes saved');
  });
}
