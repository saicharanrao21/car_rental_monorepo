import 'package:dio/dio.dart';
import 'api_client.dart';

class UploadResult {
  final String key;
  final String? publicUrl;
  final String uploadUrl;

  const UploadResult({
    required this.key,
    this.publicUrl,
    required this.uploadUrl,
  });
}

class UploadService {
  final ApiClient apiClient;

  UploadService({required this.apiClient});

  /// Uploads binary file bytes using the canonical backend presigned upload flow.
  /// 1. Requests a presigned PUT URL via `POST /uploads/presign`.
  /// 2. Performs a raw binary PUT directly to the target storage endpoint.
  /// 3. Returns the persisted storage [key] and optional [publicUrl].
  Future<UploadResult> uploadFileBytes({
    required String fileType,
    required String contentType,
    required List<int> fileBytes,
  }) async {
    // 1. Obtain presigned upload URL
    final presignResponse = await apiClient.dio.post(
      '/uploads/presign',
      data: {
        'fileType': fileType,
        'contentType': contentType,
      },
    );

    final data = Map<String, dynamic>.from(presignResponse.data as Map);
    final uploadUrl = data['uploadUrl'] as String;
    final key = data['key'] as String;
    final publicUrl = data['publicUrl'] as String?;

    // 2. Binary PUT to the storage target
    // Using a separate un-intercepted Dio instance so Authorization bearer headers are never leaked to external S3/R2 endpoints
    final rawDio = Dio();
    final putResponse = await rawDio.put(
      uploadUrl,
      data: Stream.fromIterable([fileBytes]),
      options: Options(
        headers: {
          Headers.contentLengthHeader: fileBytes.length,
          Headers.contentTypeHeader: contentType,
        },
      ),
    );

    if (putResponse.statusCode != 200 && putResponse.statusCode != 201) {
      throw DioException(
        requestOptions: RequestOptions(path: uploadUrl),
        error: 'Storage upload failed with status ${putResponse.statusCode}',
      );
    }

    return UploadResult(
      key: key,
      publicUrl: publicUrl,
      uploadUrl: uploadUrl,
    );
  }
}
