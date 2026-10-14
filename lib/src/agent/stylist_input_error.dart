/// User-actionable failures that leave the last committed outfit intact.
enum StylistInputErrorCode {
  budgetConflict,
  invalidSelection,
  invalidAdjustment,
  unsupportedAction,
  invalidBrief,
}

/// A safe, host-authored explanation of an instruction that cannot be applied.
///
/// Keep provider details and model/protocol failures out of this type. Those
/// failures need connection recovery; this type lets the person edit their
/// instruction or use the current outfit controls without retrying it.
class StylistInputError implements Exception {
  const StylistInputError({required this.code, required this.message});

  final StylistInputErrorCode code;
  final String message;

  @override
  String toString() => 'StylistInputError(${code.name}): $message';
}
