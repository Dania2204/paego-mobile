import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opaego/core/config/api_config.dart';

void main() {
  test('sin .env la app apunta a la producción en Azure', () {
    dotenv.testLoad(fileInput: '');
    expect(ApiConfig.baseUrl, 'https://azwafmsbgbksw4m22.azurewebsites.net');
  });

  test('PAEGO_API_URL manda y se le quita la barra final', () {
    dotenv.testLoad(fileInput: 'PAEGO_API_URL=http://10.0.2.2:8000/');
    expect(ApiConfig.baseUrl, 'http://10.0.2.2:8000');
    expect(
      ApiConfig.uri('/envios/').toString(),
      'http://10.0.2.2:8000/api/envios/',
    );
  });
}
