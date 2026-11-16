import 'dart:async';

import 'package:livewell/features/profile/data/data_export.dart';

/// In-memory "Download my data" (T-CMP-03): the test moves the job along.
class FakeDataExports implements DataExports {
  final _jobs = StreamController<DataExportJob?>.broadcast();
  DataExportJob? latest;
  int requests = 0;
  final links = <String>[];
  final opened = <Uri>[];

  /// What [request] does: throw this instead of starting a job.
  Object? requestError;

  /// What [downloadLink] does: throw this instead.
  Object? linkError;

  void emit(DataExportJob? job) {
    latest = job;
    _jobs.add(job);
  }

  @override
  Stream<DataExportJob?> watchLatest() async* {
    yield latest;
    yield* _jobs.stream;
  }

  @override
  Future<void> request() async {
    final e = requestError;
    if (e != null) throw e;
    requests++;
    emit(DataExportJob(id: 'job$requests', status: DataExportStatus.preparing));
  }

  @override
  Future<Uri> downloadLink(String jobId) async {
    final e = linkError;
    if (e != null) throw e;
    links.add(jobId);
    return Uri.parse('https://storage.example/exports/$jobId.zip?sig=x');
  }

  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}
