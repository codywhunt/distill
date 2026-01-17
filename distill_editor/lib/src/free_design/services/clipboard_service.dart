import 'package:flutter/services.dart';

import 'clipboard_payload.dart';

/// Type of clipboard operation performed.
enum ClipboardOperation {
  /// Standard copy (Cmd+C)
  copy,

  /// Cut operation (Cmd+X)
  cut,

  /// Duplicate operation (Cmd+D)
  duplicate,
}

/// Service for managing clipboard operations with dual clipboard support.
///
/// Uses both an internal (in-memory) clipboard and the system clipboard:
/// - Internal clipboard: Fast, reliable, synchronous access for duplicate
/// - System clipboard: Interoperability with other apps, async
///
/// Paste prefers internal clipboard if a recent copy/cut was performed,
/// otherwise falls back to system clipboard.
class ClipboardService {
  /// In-memory clipboard for fast, reliable operations.
  ClipboardPayload? _internalClipboard;

  /// Type of the last clipboard operation.
  ClipboardOperation? _lastOperation;

  /// Copy to both internal and system clipboards.
  ///
  /// The system clipboard write is best-effort and doesn't block.
  Future<void> copy(ClipboardPayload payload) async {
    _internalClipboard = payload;
    _lastOperation = ClipboardOperation.copy;

    // Best-effort system clipboard write (don't await in critical path)
    _writeToSystemClipboard(payload);
  }

  /// Cut to both internal and system clipboards.
  ///
  /// Same as copy, but records the operation type for paste logic.
  Future<void> cut(ClipboardPayload payload) async {
    _internalClipboard = payload;
    _lastOperation = ClipboardOperation.cut;

    // Best-effort system clipboard write
    _writeToSystemClipboard(payload);
  }

  /// Mark as duplicate operation (internal only, no system clipboard).
  void markDuplicate() {
    _lastOperation = ClipboardOperation.duplicate;
  }

  /// Get internal clipboard synchronously (for duplicate).
  ///
  /// Returns the internal clipboard contents without async system clipboard access.
  ClipboardPayload? getInternal() => _internalClipboard;

  /// Paste: prefer internal clipboard, fallback to system.
  ///
  /// Returns internal clipboard if:
  /// - Internal clipboard exists AND
  /// - Last operation was copy or cut (not duplicate or nothing)
  ///
  /// Otherwise attempts to read from system clipboard, falling back
  /// to internal clipboard if system read fails.
  Future<ClipboardPayload?> paste() async {
    // Prefer internal if last op was copy/cut in this session
    if (_internalClipboard != null &&
        _lastOperation != null &&
        _lastOperation != ClipboardOperation.duplicate) {
      return _internalClipboard;
    }

    // Try system clipboard
    final systemPayload = await _readFromSystemClipboard();
    if (systemPayload != null) {
      return systemPayload;
    }

    // Last resort: return internal clipboard
    return _internalClipboard;
  }

  /// Clear the internal clipboard.
  void clear() {
    _internalClipboard = null;
    _lastOperation = null;
  }

  /// Whether there's anything in the internal clipboard.
  bool get hasContent => _internalClipboard != null;

  /// The last operation type.
  ClipboardOperation? get lastOperation => _lastOperation;

  /// Write payload to system clipboard (best-effort, fire-and-forget).
  void _writeToSystemClipboard(ClipboardPayload payload) {
    Clipboard.setData(ClipboardData(text: payload.toJsonString()))
        .catchError((_) {
      // Ignore failures (e.g., web clipboard permissions)
      return null;
    });
  }

  /// Read payload from system clipboard.
  Future<ClipboardPayload?> _readFromSystemClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      if (data?.text != null) {
        return ClipboardPayload.tryFromJson(data!.text!);
      }
    } catch (_) {
      // Ignore errors (permissions, unavailable, etc.)
    }
    return null;
  }
}
