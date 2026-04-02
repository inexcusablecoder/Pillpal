import 'package:dio/dio.dart';

/// Maps FastAPI / Dio errors to a short user-facing string.
String messageFromDio(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) {
        return first['msg'].toString();
      }
    }
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map && first['msg'] != null) {
        return first['msg'].toString();
      }
    }
  }
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.badCertificate) {
    return 'Cannot connect to server. Is the backend running? Check API URL in constants.dart.';
  }
  return 'Something went wrong. Please try again.';
}
