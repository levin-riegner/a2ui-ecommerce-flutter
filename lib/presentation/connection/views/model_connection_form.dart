import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/l10n/l10n.dart';
import '../service/session_connection.dart';
import '../../stylist/bloc/commerce_session.dart';
import '../../../data/stylist/model/model_settings.dart';
import '../bloc/connection_bloc.dart';

/// Configures a bundled provider without making a model request.
class ModelConnectionForm extends StatefulWidget {
  const ModelConnectionForm({
    super.key,
    required this.onConnected,
    required this.connectionFactory,
  });

  final ValueChanged<CommerceSession> onConnected;
  final StylistConnectionFactory connectionFactory;

  @override
  State<ModelConnectionForm> createState() => _ModelConnectionFormState();
}

class _ModelConnectionFormState extends State<ModelConnectionForm> {
  final _form = GlobalKey<FormState>();
  final _model = TextEditingController();
  final _key = TextEditingController();
  final _baseUrl = TextEditingController();
  late final _bloc = ConnectionBloc(
    coordinator: SessionConnection(connect: widget.connectionFactory),
  );

  @override
  void dispose() {
    // Closing cancels ownership immediately, even if the factory resolves late.
    unawaited(_bloc.close());
    _key.clear();
    _model.dispose();
    _key.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  void _connect() {
    if (!_bloc.state.canSubmit || !_form.currentState!.validate()) return;
    _bloc.submit(
      model: _model.text.trim(),
      apiKey: _key.text.trim(),
      baseUrl: _baseUrl.text.trim(),
    );
    _key.clear();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _bloc,
    child: BlocConsumer<ConnectionBloc, ConnectionState>(
      listener: (context, state) {
        if (state.status != ConnectionStatus.connected) return;
        final session = _bloc.takeConnectedSession();
        if (session != null) widget.onConnected(session);
      },
      builder: (context, state) {
        final l10n = context.l10n;
        String? requiredValue(String? value) =>
            value == null || value.trim().isEmpty ? l10n.fieldRequired : null;
        return Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.connectionTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.connectionPrivacyNotice),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: state.provider,
                decoration: InputDecoration(labelText: l10n.connectionProvider),
                items: [
                  DropdownMenuItem(
                    value: 'googleai',
                    child: Text(l10n.connectionProviderGoogle),
                  ),
                  DropdownMenuItem(
                    value: 'openai',
                    child: Text(l10n.connectionProviderOpenAi),
                  ),
                  DropdownMenuItem(
                    value: 'anthropic',
                    child: Text(l10n.connectionProviderAnthropic),
                  ),
                  DropdownMenuItem(
                    value: 'openai-compatible',
                    child: Text(l10n.connectionProviderCompatible),
                  ),
                ],
                onChanged: state.canSubmit
                    ? (value) {
                        if (value != null) {
                          _bloc.add(ConnectionProviderChanged(value));
                        }
                      }
                    : null,
              ),
              if (state.provider == 'openai-compatible') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _baseUrl,
                  enabled: state.canSubmit,
                  decoration: InputDecoration(
                    labelText: l10n.connectionBaseUrl,
                    hintText: l10n.connectionBaseUrlHint,
                  ),
                  validator: (value) => providerApiUrl(value ?? '') == null
                      ? l10n.connectionInvalidBaseUrl
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _model,
                enabled: state.canSubmit,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: l10n.connectionModelId),
                validator: requiredValue,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _key,
                enabled: state.canSubmit,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: l10n.connectionApiKey),
                validator: requiredValue,
              ),
              const SizedBox(height: 12),
              Text(l10n.connectionUsageNotice),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(l10n.connectionFailure),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.canSubmit ? _connect : null,
                child: state.isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.connectionSubmit),
              ),
            ],
          ),
        );
      },
    ),
  );
}
