import '../service/session_connection.dart';

sealed class ConnectionEvent {
  const ConnectionEvent();
}

final class ConnectionProviderChanged extends ConnectionEvent {
  const ConnectionProviderChanged(this.provider);

  final String provider;
}

final class ConnectionSubmitted extends ConnectionEvent {
  const ConnectionSubmitted(this.attempt);

  final ConnectionAttempt attempt;

  @override
  String toString() => 'ConnectionSubmitted(redacted)';
}

final class ConnectionConfigurationRejected extends ConnectionEvent {
  const ConnectionConfigurationRejected();
}
