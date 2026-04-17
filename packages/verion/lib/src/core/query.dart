import 'dart:async';
import 'package:async/async.dart';
import 'package:verion/src/core/subscribe_context.dart';
import 'package:verion/src/types.dart';
import 'package:verion/src/core/base.dart';

sealed class QueryState<T> {
  const QueryState();

  bool get isIdle => this is QueryIdle<T>;

  bool get isLoading => this is QueryLoading<T>;

  bool get isSuccess => this is QuerySuccess<T>;

  bool get isError => this is QueryError<T>;

  factory QueryState.idle() = QueryIdle<T>;
  factory QueryState.loading([T? result]) = QueryLoading<T>;
  factory QueryState.success(T result) = QuerySuccess<T>;
  factory QueryState.error(
    Object error, {
    StackTrace? stackTrace,
    T? previousData,
  }) = QueryError<T>;
}

final class QueryIdle<T> extends QueryState<T> {
  const QueryIdle();
}

final class QueryLoading<T> extends QueryState<T> {
  const QueryLoading([this.result]);

  final T? result;

  @override
  int get hashCode => result.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryLoading<T>) && other.result == result;
}

final class QuerySuccess<T> extends QueryState<T> {
  const QuerySuccess(this.result);

  final T result;

  @override
  int get hashCode => result.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuerySuccess<T>) && other.result == result;
}

final class QueryError<T> extends QueryState<T> {
  const QueryError(
    this.error, {
    this.previousData,
    this.stackTrace,
  });

  final Object error;
  final T? previousData;
  final StackTrace? stackTrace;

  @override
  int get hashCode => Object.hash(error, previousData);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryError<T> &&
          other.error == error &&
          other.previousData == previousData);
}

abstract interface class Query<T> implements ReadableVerion<QueryState<T>> {
  @override
  void refresh();
  void addListener(ValueCallback<QueryState<T>> fn);
  void removeListener(ValueCallback<QueryState<T>> fn);
}

final class QueryBase<T> extends ReadableVerion<QueryState<T>>
    with Parents, Children, ListenableVerion<QueryState<T>>
    implements Query<T> {
  QueryBase(
    this._fn, {
    required super.scope,
    required this.eager,
    super.label,
    this.debounce,
  }) {
    if (eager) {
      refresh();
    }
  }

  final Future<T> Function(SubscribeContext sub) _fn;
  final Duration? debounce;
  final bool eager;

  QueryState<T> _value = .idle();

  final SubscribeContext _subscribeContext = .new();

  CancelableOperation? _operation;
  Timer? _debounceTimer;
  bool _initialized = false;

  @override
  QueryState<T> get value {
    throwOnDisposed("read");
    return _value;
  }

  @override
  void refresh() {
    throwOnDisposed("refresh");

    if (!_initialized || debounce == null) {
      _initialized = true;
      _debounceTimer?.cancel();
      _handleFuture();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce!, _handleFuture);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _operation?.cancel();
    _subscribeContext.dispose();

    super.dispose();
  }

  void _handleFuture() async {
    await _operation?.cancel();
    _subscribeContext.dispose();

    final previousData = switch (_value) {
      QueryIdle() => null,
      QueryLoading(:final result) => result,
      QuerySuccess(:final result) => result,
      QueryError(:final previousData) => previousData,
    };

    _value = .loading(previousData);

    _operation =
        CancelableOperation.fromFuture(
          _fn(_subscribeContext),
          onCancel: _subscribeContext.dispose,
        ).then(
          (result) => _handleResponse(result),
          onError: (error, stackTrace) =>
              _handleError(error, stackTrace, previousData),
          onCancel: _subscribeContext.dispose,
        );
  }

  void _handleResponse(T result) {
    _value = .success(result);

    diffSubs(_subscribeContext.subscriptions);
    _subscribeContext.clearSubscriptions();

    if (hasChildren) {
      scope.scheduler.scheduleNodes(children);
    }

    if (hasListeners) {
      scope.scheduler.schedulePostFlushListener(this);
    }
  }

  void _handleError(Object error, StackTrace stackTrace, T? previousData) {
    _value = .error(error, stackTrace: stackTrace, previousData: previousData);

    diffSubs(_subscribeContext.subscriptions);
    _subscribeContext.clearSubscriptions();

    if (hasChildren) {
      scope.scheduler.scheduleNodes(children);
    }

    if (hasListeners) {
      scope.scheduler.schedulePostFlushListener(this);
    }
  }
}
