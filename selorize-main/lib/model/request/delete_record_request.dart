class DeleteRecordRequest {
  final String tableName;
  final String id;

  const DeleteRecordRequest({required this.tableName, required this.id});

  Map<String, String> toJson() {
    return {"tableName": tableName, "act": "delete", "id": id};
  }
}
