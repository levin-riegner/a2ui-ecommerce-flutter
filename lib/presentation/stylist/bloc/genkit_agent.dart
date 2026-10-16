import '../../../data/stylist/repository/stylist_repository.dart';
import 'stylist_bloc.dart';
import '../../../data/stylist/service/remote/genkit_providers.dart';
import '../../../data/stylist/service/runtime/stylist_runtime.dart';

export 'stylist_bloc.dart';

/// Compatibility name for integrations that predate the session BLoC.
/// Screen state and command processing are implemented by [StylistBloc].
class GenkitAgent extends StylistBloc {
  GenkitAgent(
    StylistRuntime runtime, {
    GenkitProvider? provider,
    super.catalog,
    super.inspector,
  }) : super(StylistRepository(runtime: runtime, provider: provider));
}
