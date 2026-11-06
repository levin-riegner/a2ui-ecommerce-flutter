/// A model that Alder can offer without remote discovery.
class ProviderModelPreset {
  const ProviderModelPreset({required this.id, required this.label});

  final String id;
  final String label;
}

/// Curated, tool-capable models for the bundled provider adapters.
///
/// OpenAI-compatible endpoints deliberately have no presets because their
/// model identifiers depend on the configured host.
const providerModelPresets = <String, List<ProviderModelPreset>>{
  'googleai': [
    ProviderModelPreset(id: 'gemini-4-argon', label: 'Gemini 4 Argon'),
    ProviderModelPreset(id: 'gemini-3.8-flash', label: 'Gemini 3.8 Flash'),
  ],
  'openai': [ProviderModelPreset(id: 'gpt-6-sol', label: 'GPT-6 Sol')],
  'anthropic': [
    ProviderModelPreset(id: 'claude-fable-5-1', label: 'Claude Fable 5.1'),
    ProviderModelPreset(id: 'claude-opus-5-5', label: 'Claude Opus 5.5'),
    ProviderModelPreset(id: 'claude-sonnet-5-5', label: 'Claude Sonnet 5.5'),
  ],
  'openai-compatible': [],
};

List<ProviderModelPreset> modelsForProvider(String provider) =>
    providerModelPresets[provider] ?? const [];

String? defaultModelForProvider(String provider) {
  final models = modelsForProvider(provider);
  return models.isEmpty ? null : models.first.id;
}
