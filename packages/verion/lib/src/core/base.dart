import 'package:meta/meta.dart';
import 'package:verion/src/core/core.dart';
import 'package:verion/src/core/scope.dart';
import 'package:verion/src/types.dart';

abstract class VerionBase {
  VerionBase({required Scope scope, String? label})
    : _label = label,
      _scope = scope {
    _scope.registerNode(this);
  }

  final String? _label;
  String get label => _label ?? runtimeType.toString();

  final Scope _scope;
  Scope get scope => _scope;

  @internal
  int get depth => 0;

  bool _disposed = false;
  bool get disposed => _disposed;

  bool dirty = false;

  @internal
  @mustBeOverridden
  void refresh();

  @internal
  @protected
  void addChild(VerionBase node) {
    throw UnsupportedError("$runtimeType does not support children.");
  }

  @internal
  @protected
  void removeChild(VerionBase node) {}

  @internal
  @protected
  void updateDepth(int parentDepth);

  @mustCallSuper
  void dispose() {
    throwOnDisposed("dispose");

    _disposed = true;

    _scope.removeNode(this);
  }

  @internal
  @protected
  void throwOnDisposed([String? action]) {
    if (!disposed) return;

    throw VerionDisposedNodeError(this, action);
  }
}

abstract class ReadableVerion<T> extends VerionBase {
  ReadableVerion({required super.scope, super.label});

  T get value;
}

mixin ListenableVerion<T> on ReadableVerion<T> {
  final List<ValueCallback<T>> _listeners = [];

  @internal
  bool get hasListeners => _listeners.isNotEmpty;

  void addListener(ValueCallback<T> fn) {
    throwOnDisposed("attach listener to");

    _listeners.add(fn);
  }

  void removeListener(ValueCallback<T> fn) => _listeners.remove(fn);

  void notifyListeners() {
    for (var i = 0; i < _listeners.length; i++) {
      _listeners[i](value);
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _listeners.clear();

    super.dispose();
  }
}

mixin Children on VerionBase {
  List<VerionBase>? _children;

  @internal
  @protected
  bool get hasChildren => _children != null && _children!.isNotEmpty;

  @internal
  @protected
  List<VerionBase> get children => _children ?? [];

  @override
  @internal
  @protected
  void addChild(VerionBase node) {
    _children ??= [];

    if (!children.contains(node)) {
      children.add(node);
    }
  }

  @override
  @internal
  @protected
  void removeChild(VerionBase node) {
    if (!hasChildren) return;

    final nodeIdx = children.indexOf(node);
    if (nodeIdx == -1) return;

    children[nodeIdx] = children.last;
    children.removeLast();
  }

  @override
  void dispose() {
    if (hasChildren) {
      while (children.isNotEmpty) {
        children.removeLast().dispose();
      }

      _children = null;
    }
    super.dispose();
  }
}

mixin Parents on VerionBase {
  List<VerionBase>? _parents;

  int _depth = 1;

  @override
  int get depth => _depth;

  @internal
  @protected
  bool get hasParents => _parents != null && _parents!.isNotEmpty;

  @internal
  @protected
  List<VerionBase> get parents => _parents!;

  @internal
  @protected
  void onParentAdded(VerionBase node) {
    updateDepth(node.depth);
  }

  @override
  void updateDepth(int parentDepth) {
    if (_depth > parentDepth) return;

    _depth = parentDepth + 1;
  }

  @internal
  @protected
  void addParent(VerionBase node) {
    if (!hasParents) _parents = [];

    if (!parents.contains(node)) {
      parents.add(node);

      node.addChild(this);

      onParentAdded(node);
    }
  }

  @internal
  @protected
  void removeParent(VerionBase node) {
    if (!hasParents) return;

    final nodeIdx = parents.indexOf(node);
    if (nodeIdx == -1) return;

    parents[nodeIdx] = parents.last;
    parents.removeLast();
  }

  @internal
  @protected
  void diffSubs(List<VerionBase> subs) {
    final oldSubs = _parents;

    // Fast Path 1: First time initialization
    if (oldSubs == null || oldSubs.isEmpty) {
      for (var i = 0; i < subs.length; i++) {
        final parent = subs[i];
        parent.addChild(this);
        onParentAdded(parent);
      }

      _parents = subs;
      return;
    }

    final oldLen = oldSubs.length;
    final newLen = subs.length;

    // Fast Path 2: Strict identity match
    if (oldLen == newLen) {
      bool isIdentical = true;

      for (var i = 0; i < oldLen; i++) {
        // Order will relatively stay the same,
        //
        // I don't see any cases where subscriptions will only change their order
        if (oldSubs[i] != subs[i]) {
          isIdentical = false;
          break;
        }
      }

      if (isIdentical) return;
    }

    // For standard UI graphs (< 30 dependencies), nested loops are faster
    // because they avoid the overhead of allocating HashSets.
    if (oldLen < 30 && newLen < 30) {
      // Old subscriptions
      for (var i = 0; i < oldLen; i++) {
        final node = oldSubs[i];

        if (!subs.contains(node)) {
          node.removeChild(this);
        }
      }

      // New subscriptions
      for (var i = 0; i < newLen; i++) {
        final node = subs[i];

        if (!oldSubs.contains(node)) {
          node.addChild(this);
          onParentAdded(node);
        }
      }
    } else {
      final oldSet = oldSubs.toSet();
      final newSet = subs.toSet();

      // removed subscriptions
      for (var i = 0; i < oldLen; i++) {
        final node = oldSubs[i];
        if (!newSet.contains(node)) {
          node.removeChild(this);
        }
      }

      // new subscriptions
      for (var i = 0; i < newLen; i++) {
        final node = subs[i];

        if (!oldSet.contains(node)) {
          node.addChild(this);
          onParentAdded(node);
        }
      }
    }

    _parents = subs;
  }

  @override
  void dispose() {
    if (hasParents) {
      while (parents.isNotEmpty) {
        parents.removeLast().removeChild(this);
      }

      _parents = null;
    }
    super.dispose();
  }
}
