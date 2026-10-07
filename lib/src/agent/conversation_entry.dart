/// Ordered content shown in the stylist conversation.
sealed class CommerceConversationEntry {
  const CommerceConversationEntry();
}

/// A submitted user message, identified independently of a model retry.
class CommerceUserMessage extends CommerceConversationEntry {
  const CommerceUserMessage({required this.id, required this.text});

  final String id;
  final String text;
}

/// A committed assistant surface retained in the conversation.
class CommerceSurfaceEntry extends CommerceConversationEntry {
  const CommerceSurfaceEntry({required this.surfaceId});

  final String surfaceId;
}
