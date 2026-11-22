import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// Cache en memoria de los bytes de las imágenes `data:` del negocio.
///
/// El logo y la imagen del sello se guardan como base64 en `config/main`
/// (plan Spark, sin Storage). Decodificarlos en cada `build` era caro: la
/// tarjeta del cliente llega a crear una imagen por sello, así que el mismo
/// base64 se decodificaba hasta 50 veces por reconstrucción.
class ImageBytesCache {
  ImageBytesCache._();

  static const int _maxEntries = 8;
  static final LinkedHashMap<String, Uint8List?> _entries =
      LinkedHashMap<String, Uint8List?>();

  /// Devuelve los bytes de una URL `data:image/...;base64,...`.
  ///
  /// Las URL normales y las entradas inválidas devuelven `null`. El resultado
  /// se reutiliza mientras la cadena de origen sea la misma, de modo que
  /// Flutter también pueda reutilizar el bitmap en su propia caché de imágenes.
  static Uint8List? dataUriBytes(String source) {
    if (!source.startsWith('data:image/')) return null;

    if (_entries.containsKey(source)) {
      final cached = _entries.remove(source);
      _entries[source] = cached;
      return cached;
    }

    Uint8List? bytes;
    try {
      final comma = source.indexOf(',');
      if (comma >= 0) {
        bytes = base64Decode(source.substring(comma + 1));
      }
    } catch (_) {
      bytes = null;
    }

    _entries[source] = bytes;
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return bytes;
  }

  /// Solo para tests: descarta todo lo cacheado.
  static void clear() => _entries.clear();
}
