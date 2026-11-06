import 'package:a2ui_flutter_commerce/data/stylist/model/provider_model_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled providers expose capability-first defaults', () {
    expect(modelsForProvider('googleai').map((model) => model.id), [
      'gemini-4-argon',
      'gemini-3.8-flash',
    ]);
    expect(defaultModelForProvider('googleai'), 'gemini-4-argon');
    expect(modelsForProvider('openai').map((model) => model.id), ['gpt-6-sol']);
    expect(defaultModelForProvider('openai'), 'gpt-6-sol');
    expect(modelsForProvider('anthropic').map((model) => model.id), [
      'claude-fable-5-1',
      'claude-opus-5-5',
      'claude-sonnet-5-5',
    ]);
    expect(defaultModelForProvider('anthropic'), 'claude-fable-5-1');
  });

  test('compatible endpoints require a manual model ID', () {
    expect(modelsForProvider('openai-compatible'), isEmpty);
    expect(defaultModelForProvider('openai-compatible'), isNull);
  });
}
