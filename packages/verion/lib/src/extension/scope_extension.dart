part of '../core/scope.dart';

extension SourceX on VerionScope {
  Source<T, E> source<T, E extends SourceEvent<T>>(
    T value, {
    EqualityCallback<T>? notifyWhen,
    String? label,
  }) => SourceBase(
    value,
    scope: _scope,
    notifyWhen: notifyWhen,
    label: label,
  );
}

extension DeriveX on VerionScope {
  Derive<T> derive<T>(
    T Function(SubscribeContext sub) fn, {
    EqualityCallback<T>? notifyWhen,
    String? label,
  }) => DeriveBase(
    fn,
    scope: _scope,
    notifyWhen: notifyWhen,
    label: label,
  );
}

extension TriggerX on VerionScope {
  Trigger trigger(void Function(SubscribeContext sub) fn, {String? label}) =>
      TriggerBase(fn, label: label, scope: _scope);
}

extension BatchX on VerionScope {
  void batch(VoidCallback fn) => _scope.scheduler.batch(fn);
}

extension QueryX on VerionScope {
  Query<T> query<T>(
    Future<T> Function(SubscribeContext sub) fn, {
    bool eager = false,
    Duration? debounce,
    String? label,
  }) => QueryBase(
    fn,
    scope: _scope,
    debounce: debounce,
    eager: eager,
    label: label,
  );
}
