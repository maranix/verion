import 'package:meta/meta.dart';

import 'package:verion/src/core/base.dart';
import 'package:verion/src/core/query.dart';
import 'package:verion/src/core/scheduler.dart';
import 'package:verion/src/core/derive.dart';
import 'package:verion/src/core/source.dart';
import 'package:verion/src/core/subscribe_context.dart';
import 'package:verion/src/core/trigger.dart';
import 'package:verion/src/types.dart';
import 'package:verion/src/observer.dart';

part '../extension/scope_extension.dart';

base class VerionScope {
  VerionScope({String? label}) : _scope = _ScopeImpl(label: label) {
    VerionObserver.instance?.onScopeCreated(this);
  }

  String get label => _scope.label;

  final Scope _scope;

  @mustCallSuper
  void dispose() {
    _scope.dispose();

    VerionObserver.instance?.onScopeDisposed(this);
  }
}

abstract interface class Scope {
  Scheduler get scheduler;

  String get label;

  void registerNode(VerionBase node);
  void removeNode(VerionBase node);

  void dispose();
}

final class _ScopeImpl implements Scope {
  _ScopeImpl({String? label, Scheduler? scheduler})
    : _scheduler = scheduler ?? Scheduler(),
      _label = label;

  final Scheduler _scheduler;

  @override
  Scheduler get scheduler => _scheduler;

  final String? _label;

  @override
  String get label => _label ?? runtimeType.toString();

  final List<VerionBase> _nodes = [];

  bool _disposed = false;

  @override
  void registerNode(VerionBase node) => _nodes.add(node);

  @override
  void removeNode(VerionBase node) {
    final idx = _nodes.indexOf(node);
    if (idx == -1) return;

    _nodes[idx] = _nodes.last;
    _nodes.removeLast();
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;

    _scheduler.dispose();

    for (var i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];

      // We only need to dispose Source nodes since they will correctly
      // propagate the dispose signal to their childrens.
      if (node is SourceBase) {
        node.dispose();
      }
    }

    _nodes.clear();
  }
}
