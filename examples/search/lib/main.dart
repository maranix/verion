import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:verion_flutter/verion_flutter.dart';

sealed class SearchInputEvent implements SourceEvent<String> {
  const SearchInputEvent();

  factory SearchInputEvent.changed(String query) = SearchInputChanged;
  factory SearchInputEvent.reset() = SearchInputReset;
}

final class SearchInputChanged extends SearchInputEvent {
  const SearchInputChanged(this.query);

  final String query;

  @override
  String reduce(state) => query;

  @override
  int get hashCode => query.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchInputChanged) && query == other.query;
}

final class SearchInputReset extends SearchInputEvent {
  const SearchInputReset();

  @override
  String reduce(state) => "";
}

final class SearchScope extends VerionScope {
  final _dio = Dio(BaseOptions(baseUrl: "https://dummyjson.com"));

  late final productQuery = source<String, SearchInputEvent>("");

  late final productQueryResults = query(
    debounce: const Duration(milliseconds: 300),
    (sub) async {
      final cancelToken = CancelToken();
      sub.onDispose(cancelToken.cancel);

      final q = sub(productQuery);

      final data = await _searchProducts(q, cancelToken);
      return data;
    },
  );

  Future<List<Map<String, dynamic>>> _searchProducts(
    String query, [
    CancelToken? cancelToken,
  ]) async {
    final res = await _dio.get(
      "/products/search",
      queryParameters: {"q": query},
      cancelToken: cancelToken,
      options: Options(responseType: .json),
    );

    if (res.statusCode != 200) {
      throw HttpException(
        res.statusMessage ?? "Something went wrong: ${res.data.toString()}",
        uri: res.realUri,
      );
    }

    final data = ((res.data["products"] as List?) ?? [])
        .cast<Map<String, dynamic>>();

    return data;
  }

  @override
  void dispose() {
    _dio.close();

    super.dispose();
  }
}

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VerionScopeProvider(scope: SearchScope(), child: ProductsPage()),
    );
  }
}

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        spacing: 8,
        children: [
          SearchInput(),
          Expanded(child: SearchResults()),
        ],
      ),
    );
  }
}

class SearchInput extends StatefulWidget {
  const SearchInput({super.key});

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  late final SearchScope _searchScope;

  void _onQueryChanged(String query) {
    _searchScope.productQuery.dispatch(.changed(query));

    if (_searchScope.productQueryResults.value.isIdle) {
      _searchScope.productQueryResults.refresh();
    }
  }

  @override
  void initState() {
    super.initState();

    _searchScope = VerionScopeProvider.of<SearchScope>(context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(onChanged: _onQueryChanged);
  }
}

class SearchResults extends StatefulWidget {
  const SearchResults({super.key});

  @override
  State<SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<SearchResults> {
  late QueryState<List<Map<String, dynamic>>> _results;
  late final SearchScope _searchScope;

  void _onResultsUpdated(QueryState<List<Map<String, dynamic>>> results) {
    setState(() {
      _results = results;
    });
  }

  @override
  void initState() {
    super.initState();

    _searchScope = VerionScopeProvider.of<SearchScope>(context);
    _results = _searchScope.productQueryResults.value;
    _searchScope.productQueryResults.addListener(_onResultsUpdated);
  }

  @override
  void dispose() {
    _searchScope.productQueryResults.removeListener(_onResultsUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_results) {
      QueryIdle() => Center(child: Text("Type something to start...")),
      QueryLoading() => Center(child: CircularProgressIndicator.adaptive()),
      QuerySuccess(:final result) => ListView.builder(
        padding: .all(4),
        itemCount: result.length,
        itemBuilder: (context, index) {
          final item = result[index];
          return Padding(
            padding: .symmetric(vertical: 8.0),
            child: Text(item["title"]),
          );
        },
      ),
      QueryError(:final error) => Center(
        child: Text("Something went wrong\n$error"),
      ),
    };
  }
}
