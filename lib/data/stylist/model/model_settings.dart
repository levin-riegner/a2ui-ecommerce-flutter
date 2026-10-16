/// User supplied settings live only for the lifetime of a model connection.
class ModelSettings {
  ModelSettings({
    required this.provider,
    required String model,
    required String apiKey,
    String? baseUrl,
  }) : model = model.trim(),
       _apiKey = apiKey.trim(),
       baseUrl = baseUrl?.trim() {
    if (!providers.contains(provider) ||
        this.model.isEmpty ||
        _apiKey.isEmpty ||
        this.model.contains(RegExp(r'[\s\x00-\x1f]')) ||
        _apiKey.contains(RegExp(r'[\r\n]')) ||
        (provider == 'openai-compatible' &&
            providerApiUrl(this.baseUrl ?? '') == null)) {
      throw const FormatException('Check your provider and model settings');
    }
  }

  static const providers = [
    'googleai',
    'openai',
    'anthropic',
    'openai-compatible',
  ];
  final String provider;
  final String model;
  final String? baseUrl;
  String _apiKey;
  String get apiKey => _apiKey;
  void clear() => _apiKey = '';

  @override
  String toString() => 'ModelSettings($provider, $model)';
}

Uri? providerApiUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final local = [
    'localhost',
    '127.0.0.1',
    '::1',
    '10.0.2.2',
  ].contains(uri.host);
  return uri.scheme == 'https' || (uri.scheme == 'http' && local) ? uri : null;
}
