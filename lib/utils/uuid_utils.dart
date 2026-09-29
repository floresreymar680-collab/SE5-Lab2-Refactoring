// lib/utils/uuid_utils.dart
// ─────────────────────────────────────────────────────────────────────────────
// UUID generation utility (wraps the uuid package)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a UUID v4 string.
/// Used for: document storage file names, local cache keys, etc.
String generateUUID() => _uuid.v4();
