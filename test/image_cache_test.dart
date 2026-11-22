import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tarjet_fidel/utils/image_cache.dart';

String dataUri(String text) =>
    'data:image/png;base64,${base64Encode(utf8.encode(text))}';

void main() {
  setUp(ImageBytesCache.clear);

  test('decodifica una URL data:image', () {
    final bytes = ImageBytesCache.dataUriBytes(dataUri('logo'));
    expect(bytes, isNotNull);
    expect(utf8.decode(bytes!), 'logo');
  });

  test('reutiliza los bytes para la misma imagen', () {
    final source = dataUri('sello');
    final first = ImageBytesCache.dataUriBytes(source);
    final second = ImageBytesCache.dataUriBytes(source);
    expect(second, same(first));
  });

  test('devuelve null para URL normales y datos inválidos', () {
    expect(
      ImageBytesCache.dataUriBytes('https://ejemplo.com/logo.png'),
      isNull,
    );
    expect(ImageBytesCache.dataUriBytes('data:image/png;base64,!!!'), isNull);
    expect(ImageBytesCache.dataUriBytes('data:image/png'), isNull);
  });

  test('descarta la entrada más antigua cuando se llena', () {
    final firstSource = dataUri('primera');
    final first = ImageBytesCache.dataUriBytes(firstSource);
    for (var i = 0; i < 9; i++) {
      ImageBytesCache.dataUriBytes(dataUri('extra-$i'));
    }
    final again = ImageBytesCache.dataUriBytes(firstSource);
    expect(again, isNotNull);
    expect(again, isNot(same(first)));
  });
}
