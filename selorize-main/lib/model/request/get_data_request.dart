class GetDataRequest {
  final String tableName;
  final Map<String, dynamic> filter;

  const GetDataRequest({required this.tableName, this.filter = const {}});

  Map<String, dynamic> toJson() {
    return {"tableName": tableName, ...filter};
  }
}
