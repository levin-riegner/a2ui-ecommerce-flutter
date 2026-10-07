import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'genkit_agent.dart';
import 'model_settings.dart';

/// Configures a bundled Genkit provider without making a model request.
class ModelConnectionForm extends StatefulWidget {
  const ModelConnectionForm({
    super.key,
    required this.onConnected,
    this.client,
  });

  final ValueChanged<GenkitAgent> onConnected;
  final http.Client? client;

  @override
  State<ModelConnectionForm> createState() => _ModelConnectionFormState();
}

class _ModelConnectionFormState extends State<ModelConnectionForm> {
  final _form = GlobalKey<FormState>();
  final _model = TextEditingController();
  final _key = TextEditingController();
  final _baseUrl = TextEditingController();
  String _provider = 'googleai';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _model.dispose();
    _key.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final agent = await GenkitAgent.connect(
        onlineContext: true,
        provider: _provider,
        model: _model.text.trim(),
        apiKey: _key.text.trim(),
        baseUrl: _provider == 'openai-compatible' ? _baseUrl.text.trim() : null,
        client: widget.client,
      );
      if (!mounted) {
        agent.dispose();
        return;
      }
      _key.clear();
      widget.onConnected(agent);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not configure your model. Check the provider and model settings.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect your model',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Bring your own API key. Your key stays in memory on this device and is sent directly to your chosen provider. It is not saved.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: const [
              DropdownMenuItem(value: 'googleai', child: Text('Google Gemini')),
              DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
              DropdownMenuItem(value: 'anthropic', child: Text('Anthropic')),
              DropdownMenuItem(
                value: 'openai-compatible',
                child: Text('OpenAI-compatible'),
              ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _provider = value!;
                    _error = null;
                  }),
          ),
          if (_provider == 'openai-compatible') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _baseUrl,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Provider API base URL',
                hintText: 'https://your-provider.example/v1',
              ),
              validator: (value) => providerApiUrl(value ?? '') == null
                  ? 'Use HTTPS or a local loopback HTTP address'
                  : null,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _model,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Model ID'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _key,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'API key'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          const Text(
            'Connecting makes no model request. Starting a journey, chatting, selecting pieces, and retrying use your provider account and may incur charges.',
          ),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!)],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _connect,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect model'),
          ),
        ],
      ),
    );
  }
}
