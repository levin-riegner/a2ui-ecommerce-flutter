import 'package:equatable/equatable.dart';

enum ConnectionStatus { idle, connecting, connected, failure }

enum ConnectionError { configuration }

/// Only presentation values belong here; credentials and sessions never do.
class ConnectionState extends Equatable {
  const ConnectionState({
    this.provider = 'googleai',
    this.status = ConnectionStatus.idle,
    this.error,
  });

  final String provider;
  final ConnectionStatus status;
  final ConnectionError? error;

  @override
  List<Object?> get props => [provider, status, error];

  bool get isBusy => status == ConnectionStatus.connecting;
  bool get canSubmit =>
      status == ConnectionStatus.idle || status == ConnectionStatus.failure;
}
