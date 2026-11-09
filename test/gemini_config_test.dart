import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opaego/core/config/gemini_config.dart';

void main() {
  test('lee la clave de GEMINI_API_KEY', () {
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY= clave-123 \nGEMINI_MODEL=gemini-x');
    expect(GeminiConfig.clave, 'clave-123');
    expect(GeminiConfig.modelo, 'gemini-x');
  });

  test('sin configurar: clave vacía y modelo por defecto', () {
    dotenv.testLoad(fileInput: 'PAEGO_API_URL=http://x');
    expect(GeminiConfig.clave, isEmpty);
    expect(GeminiConfig.modelo, GeminiConfig.modeloPorDefecto);
  });
}
