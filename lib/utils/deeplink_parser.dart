/// Extracts an inviteId from URIs like `https://domain/invite/{id}`
String? extractInviteId(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length == 2 && segments[0] == 'invite') {
    final id = segments[1].trim();
    return id.isEmpty ? null : id;
  }
  return null;
}
