class CategoryModel {
  final String tid;
  final String name;
  final List<FilterModel>? filters;

  CategoryModel({
    required this.tid,
    required this.name,
    this.filters,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      tid: json['tid'] ?? '',
      name: json['name'] ?? '',
      filters: json['filters'] != null
          ? (json['filters'] as List)
              .map((e) => FilterModel.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tid': tid,
      'name': name,
      'filters': filters?.map((e) => e.toJson()).toList(),
    };
  }
}

class FilterModel {
  final String key;
  final String name;
  final List<FilterValue> values;

  FilterModel({
    required this.key,
    required this.name,
    required this.values,
  });

  factory FilterModel.fromJson(Map<String, dynamic> json) {
    return FilterModel(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      values: (json['values'] as List)
          .map((e) => FilterValue.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'values': values.map((e) => e.toJson()).toList(),
    };
  }
}

class FilterValue {
  final String n;
  final String v;

  FilterValue({required this.n, required this.v});

  factory FilterValue.fromJson(Map<String, dynamic> json) {
    return FilterValue(
      n: json['n'] ?? '',
      v: json['v'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'n': n,
      'v': v,
    };
  }
}