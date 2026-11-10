import 'package:certifeasy/core/utils/email_address_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aceita endereços normais, inclusive institucionais e de outros domínios', () {
    for (final ok in [
      'ana@gmail.com',
      ' bruno@ifce.edu.br ',
      'carla@aluno.ifce.edu.br',
      'd@ymail.com',
      'e@hotmail.com.br',
      'f@ifpe.edu.br',
      'g@empresa.com',
    ]) {
      expect(checkEmailAddress(ok), isNull, reason: ok);
    }
  });

  test('explica endereço vazio, sem @ ou com espaço', () {
    expect(checkEmailAddress('')!.reason, contains('vazia'));
    expect(checkEmailAddress(null)!.reason, contains('vazia'));
    expect(checkEmailAddress('ana.gmail.com')!.reason, contains('@'));
    expect(checkEmailAddress('ana@@gmail.com')!.reason, contains('mais de um @'));
    final space = checkEmailAddress('ana silva@gmail.com')!;
    expect(space.reason, contains('espaço'));
    expect(space.suggestion, 'anasilva@gmail.com');
    expect(checkEmailAddress('ana@gmail')!.reason, contains('formato'));
    expect(checkEmailAddress('ana@gmail..com')!.reason, contains('formato'));
  });

  test('sugere o provedor certo para domínio digitado errado', () {
    expect(checkEmailAddress('ana@gmial.com')!.suggestion, 'ana@gmail.com');
    expect(checkEmailAddress('ana@gmail.con')!.suggestion, 'ana@gmail.com');
    expect(checkEmailAddress('ana@hotmal.com')!.suggestion, 'ana@hotmail.com');
    expect(checkEmailAddress('ana@outlok.com')!.suggestion, 'ana@outlook.com');
  });
}
