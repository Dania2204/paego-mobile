import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dónde vive la clave del cofre (Keystore/Keychain; en pruebas, memoria).
abstract class AlmacenClave {
  Future<String?> leer();
  Future<void> guardar(String valor);
  Future<void> borrar();
}

class AlmacenClaveSeguro implements AlmacenClave {
  static const _nombre = 'paego_cofre_rostros';
  final _almacen = const FlutterSecureStorage();

  @override
  Future<String?> leer() => _almacen.read(key: _nombre);

  @override
  Future<void> guardar(String valor) =>
      _almacen.write(key: _nombre, value: valor);

  /// Sin el plugin (pruebas en la VM de Dart) nunca se guardó una clave, así
  /// que no hay nada que borrar; no debe impedir cerrar la sesión.
  @override
  Future<void> borrar() async {
    try {
      await _almacen.delete(key: _nombre);
    } on MissingPluginException {
      return;
    }
  }
}

class AlmacenClaveEnMemoria implements AlmacenClave {
  String? _valor;

  @override
  Future<String?> leer() async => _valor;

  @override
  Future<void> guardar(String valor) async => _valor = valor;

  @override
  Future<void> borrar() async => _valor = null;
}

/// Cifra con AES-256-GCM las plantillas faciales guardadas en el teléfono
/// (dato sensible, Ley 1581 art. 5). La clave se genera en el teléfono, vive
/// en el almacén seguro del sistema y se borra al cerrar sesión, con lo que
/// la caché queda ilegible aunque alguien copie la base SQLite.
class Cofre {
  Cofre([AlmacenClave? almacen]) : _almacen = almacen ?? AlmacenClaveSeguro();

  final AlmacenClave _almacen;
  final _aes = AesGcm.with256bits();
  SecretKey? _clave;

  Future<SecretKey> _obtenerClave() async {
    final actual = _clave;
    if (actual != null) return actual;
    final guardada = await _almacen.leer();
    if (guardada != null) {
      return _clave = SecretKey(base64Decode(guardada));
    }
    final azar = Random.secure();
    final bytes = List<int>.generate(32, (_) => azar.nextInt(256));
    await _almacen.guardar(base64Encode(bytes));
    return _clave = SecretKey(bytes);
  }

  Future<String> cifrar(Object? datos) async {
    final caja = await _aes.encrypt(
      utf8.encode(jsonEncode(datos)),
      secretKey: await _obtenerClave(),
    );
    return base64Encode(caja.concatenation());
  }

  /// Lanza [SecretBoxAuthenticationError] si la clave cambió o el texto fue alterado.
  Future<dynamic> descifrar(String texto) async {
    final caja = SecretBox.fromConcatenation(
      base64Decode(texto),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    final claro = await _aes.decrypt(caja, secretKey: await _obtenerClave());
    return jsonDecode(utf8.decode(claro));
  }

  /// Olvida la clave: lo cifrado con ella ya no se puede leer.
  Future<void> destruirClave() async {
    _clave = null;
    await _almacen.borrar();
  }
}
