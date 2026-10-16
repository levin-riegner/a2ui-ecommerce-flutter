/// Stable machine-readable rejection; [message] is safe to show to the person.
/// Domain-specific input errors remain available at the host command boundary.
enum StylistToolErrorCode { invalidInput }

class StylistToolError {
  StylistToolError({
    required this.message,
    this.code = StylistToolErrorCode.invalidInput,
    Iterable<String>? missingFields,
    Iterable<String>? clarificationRequests,
  }) : missingFields = missingFields == null
           ? null
           : List.unmodifiable(missingFields),
       clarificationRequests = clarificationRequests == null
           ? null
           : List.unmodifiable(clarificationRequests);
  factory StylistToolError.fromMap(Map<String, Object?> value) =>
      StylistToolError(
        message: value['error'] as String,
        missingFields: (value['missingFields'] as List?)?.cast<String>(),
        clarificationRequests: (value['clarificationRequests'] as List?)
            ?.cast<String>(),
      );
  final StylistToolErrorCode code;
  final String message;
  final List<String>? missingFields;
  final List<String>? clarificationRequests;
  Map<String, Object?> toJson() => Map.unmodifiable({
    'code': 'invalid_input',
    'error': message,
    'missingFields': ?missingFields,
    'clarificationRequests': ?clarificationRequests,
  });
}
