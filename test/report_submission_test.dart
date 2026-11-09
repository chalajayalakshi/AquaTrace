import 'dart:async';

import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/errors/app_exception.dart';
import 'package:aquatrace/core/models/report_model.dart';
import 'package:aquatrace/core/services/auth_service.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/core/services/preferences_service.dart';
import 'package:aquatrace/core/services/report_submission_gateway.dart';
import 'package:aquatrace/core/models/mock_data.dart';
import 'package:aquatrace/features/reports/presentation/citizen_report_form_screen.dart';
import 'package:aquatrace/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aquatrace/features/reports/services/citizen_report_input_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Citizen report persistence', () {
    test('uploads evidence before saving the pending report', () async {
      final gateway = FakeReportSubmissionGateway();
      final repository = DataRepository(reportSubmissionGateway: gateway);
      final report = buildReport();

      await repository.addReport(
        report,
        evidenceBytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
      );

      expect(gateway.calls, ['upload', 'create']);
      final saved = repository.getReportById(report.reportId)!;
      expect(saved.reporterUid, 'citizen-test-uid');
      expect(saved.latitude, 6.912345);
      expect(saved.longitude, 79.812345);
      expect(saved.beforeImageUrl, 'https://storage.example/evidence.jpg');
      expect(saved.status, FaultStatus.pending);
      expect(saved.createdAt, report.createdAt);
      expect(saved.updatedAt, isNull);
    });

    test(
      'does not save or expose a report when evidence upload fails',
      () async {
        final gateway = FakeReportSubmissionGateway()
          ..uploadError = const DatabaseException('upload failed');
        final repository = DataRepository(reportSubmissionGateway: gateway);
        final report = buildReport();

        await expectLater(
          repository.addReport(
            report,
            evidenceBytes: Uint8List.fromList([1]),
            contentType: 'image/jpeg',
          ),
          throwsA(isA<DatabaseException>()),
        );

        expect(gateway.calls, ['upload']);
        expect(repository.getReportById(report.reportId), isNull);
      },
    );

    test('does not expose a report when Firestore creation fails', () async {
      final gateway = FakeReportSubmissionGateway()
        ..createError = const DatabaseException('firestore failed');
      final repository = DataRepository(reportSubmissionGateway: gateway);
      final report = buildReport();

      await expectLater(
        repository.addReport(
          report,
          evidenceBytes: Uint8List.fromList([1]),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(gateway.calls, ['upload', 'create']);
      expect(repository.getReportById(report.reportId), isNull);
    });

    test(
      'rejects duplicate in-flight submissions with the same report ID',
      () async {
        final gateway = FakeReportSubmissionGateway()
          ..uploadCompleter = Completer<String>();
        final repository = DataRepository(reportSubmissionGateway: gateway);
        final report = buildReport();
        final submission = repository.addReport(
          report,
          evidenceBytes: Uint8List.fromList([1]),
          contentType: 'image/jpeg',
        );

        await Future<void>.delayed(Duration.zero);
        await expectLater(
          repository.addReport(
            report,
            evidenceBytes: Uint8List.fromList([1]),
            contentType: 'image/jpeg',
          ),
          throwsA(isA<ValidationException>()),
        );

        gateway.uploadCompleter!.complete(
          'https://storage.example/evidence.jpg',
        );
        await submission;
        expect(gateway.calls, ['upload', 'create']);
      },
    );

    test('rejects invalid photo data before any backend call', () async {
      final gateway = FakeReportSubmissionGateway();
      final repository = DataRepository(reportSubmissionGateway: gateway);

      await expectLater(
        repository.addReport(
          buildReport(),
          evidenceBytes: Uint8List(0),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(gateway.calls, isEmpty);
    });

    test('rejects invalid coordinates before uploading evidence', () async {
      final gateway = FakeReportSubmissionGateway();
      final repository = DataRepository(reportSubmissionGateway: gateway);

      await expectLater(
        repository.addReport(
          buildReport().copyWith(latitude: double.nan),
          evidenceBytes: Uint8List.fromList([1]),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(gateway.calls, isEmpty);
    });

    test('rejects resubmitting an already saved report ID', () async {
      final gateway = FakeReportSubmissionGateway();
      final repository = DataRepository(reportSubmissionGateway: gateway);
      final report = buildReport();

      await repository.addReport(
        report,
        evidenceBytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
      );
      await expectLater(
        repository.addReport(
          report,
          evidenceBytes: Uint8List.fromList([1]),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(gateway.calls, ['upload', 'create']);
    });
  });

  testWidgets('form shows required location and evidence errors', (
    tester,
  ) async {
    await pumpReportForm(tester, FakeCitizenReportInputProvider());
    await tester.scrollUntilVisible(
      find.text('Submit Report'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(
      find.text('Get your current GPS location to continue.'),
      findsOneWidget,
    );
    expect(find.text('Add a photo of the fault to continue.'), findsOneWidget);
    expect(find.text('Choose a fault type.'), findsOneWidget);
    expect(find.text('Choose a severity.'), findsOneWidget);
    expect(find.text('Enter at least 10 characters.'), findsOneWidget);
    expect(find.text('Enter a nearby street or landmark.'), findsOneWidget);
  });

  testWidgets('denied location permission is explained and settings offered', (
    tester,
  ) async {
    final input = FakeCitizenReportInputProvider()
      ..locationError = const PermissionException('Location permission denied.')
      ..locationPermissionPermanentlyDenied = true;
    await pumpReportForm(tester, input);

    await tapFormAction(tester, 'Get current location');

    expect(find.text('Location permission denied.'), findsOneWidget);
    expect(find.text('Open location settings'), findsOneWidget);
  });

  testWidgets('unavailable GPS gives a retryable explanation', (tester) async {
    final input = FakeCitizenReportInputProvider()
      ..locationError = const LocationServiceDisabledException();
    await pumpReportForm(tester, input);

    await tapFormAction(tester, 'Get current location');

    expect(
      find.text('Location services are turned off. Enable GPS and try again.'),
      findsOneWidget,
    );
    expect(find.text('Confirm this location'), findsNothing);
  });

  testWidgets('gallery cancellation leaves evidence required', (tester) async {
    final input = FakeCitizenReportInputProvider();
    await pumpReportForm(tester, input);

    await tapFormAction(tester, 'Choose photo');

    expect(
      find.text('No photo selected. Add a photo to continue.'),
      findsOneWidget,
    );
    expect(input.selectedSources, [ImageSource.gallery]);
  });

  testWidgets('camera permission failure offers the gallery fallback', (
    tester,
  ) async {
    final input = FakeCitizenReportInputProvider()
      ..photoError = PlatformException(code: 'camera-denied');
    await pumpReportForm(tester, input);

    await tapFormAction(tester, 'Take photo');

    expect(
      find.text(
        'Camera access failed. Check camera permission or choose a photo from your library.',
      ),
      findsOneWidget,
    );
    expect(find.text('Choose photo'), findsOneWidget);
  });

  testWidgets('valid form submits report and returns success', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pref_last_auth_uid': MockData.citizenUser.uid,
    });
    final input = FakeCitizenReportInputProvider()
      ..position = buildPosition()
      ..photo = XFile.fromData(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
        name: 'fault.jpg',
        path: 'fault.jpg',
        mimeType: 'image/jpeg',
      );
    final gateway = FakeReportSubmissionGateway();
    final repository = DataRepository(reportSubmissionGateway: gateway);
    final preferences = PreferencesService(
      await SharedPreferences.getInstance(),
    );
    final authService = AuthService(preferences);
    await tester.pump();
    final authProvider = AuthProvider(authService);
    final navigator = ReportFormTestNavigator(input: input);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: repository),
          ChangeNotifierProvider.value(value: authProvider),
        ],
        child: MaterialApp(home: navigator),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open report form'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<FaultType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pipe Leak').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'Water is leaking from a pipe beside the road.',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'Test Street, Colombo 03',
    );
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'High'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'High'));
    await tester.pumpAndSettle();

    await tapFormAction(tester, 'Get current location');
    expect(find.text('Review your GPS location'), findsOneWidget);
    await tapFormAction(tester, 'Confirm this location');
    expect(find.text('Location confirmed'), findsOneWidget);
    await tapFormAction(tester, 'Choose photo');
    expect(find.text('fault.jpg'), findsOneWidget);
    expect(find.text('Pipe Leak'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'High'), findsOneWidget);
    await tapFormAction(tester, 'Submit Report');

    expect(gateway.calls, ['upload', 'create']);
    expect(
      tester
          .state<_ReportFormTestNavigatorState>(
            find.byType(ReportFormTestNavigator, skipOffstage: false),
          )
          .submissionResult,
      isTrue,
    );
    final savedReport = gateway.createdReport!;
    expect(savedReport.reporterUid, authService.currentUser!.uid);
    expect(savedReport.reporterUid, MockData.citizenUser.uid);
    expect(savedReport.faultType, FaultType.pipeLeak);
    expect(
      savedReport.description,
      'Water is leaking from a pipe beside the road.',
    );
    expect(savedReport.severity, FaultSeverity.high);
    expect(savedReport.latitude, 6.912345);
    expect(savedReport.longitude, 79.812345);
    expect(savedReport.address, 'Test Street, Colombo 03');
    expect(savedReport.beforeImageUrl, 'https://storage.example/evidence.jpg');
    expect(savedReport.status, FaultStatus.pending);
    expect(savedReport.createdAt.isUtc, isTrue);
    expect(repository.getReportById(savedReport.reportId), isNotNull);
    expect(find.text('Report Water Fault'), findsNothing);
  });
}

Future<void> pumpReportForm(
  WidgetTester tester,
  FakeCitizenReportInputProvider input,
) async {
  final repository = DataRepository(
    reportSubmissionGateway: FakeReportSubmissionGateway(),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: repository)],
      child: MaterialApp(home: CitizenReportFormScreen(inputProvider: input)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapFormAction(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

ReportModel buildReport() {
  return ReportModel(
    reportId: 'AT-2026-test-report-001',
    reporterUid: 'citizen-test-uid',
    reporterName: 'Test Citizen',
    faultType: FaultType.pipeLeak,
    description: 'Water is leaking from a pipe near the road.',
    severity: FaultSeverity.high,
    status: FaultStatus.pending,
    latitude: 6.912345,
    longitude: 79.812345,
    address: 'Test Street, Colombo',
    createdAt: DateTime.utc(2026, 11, 9, 6),
  );
}

class FakeReportSubmissionGateway implements ReportSubmissionGateway {
  final List<String> calls = [];
  Object? uploadError;
  Object? createError;
  Completer<String>? uploadCompleter;
  ReportModel? createdReport;

  @override
  Future<String> uploadEvidence({
    required ReportModel report,
    required Uint8List bytes,
    required String contentType,
  }) async {
    calls.add('upload');
    if (uploadError case final error?) throw error;
    if (uploadCompleter case final completer?) return completer.future;
    return 'https://storage.example/evidence.jpg';
  }

  @override
  Future<void> createReport(ReportModel report) async {
    calls.add('create');
    if (createError case final error?) throw error;
    createdReport = report;
  }
}

class FakeCitizenReportInputProvider implements CitizenReportInputProvider {
  Object? locationError;
  Object? photoError;
  @override
  bool locationPermissionPermanentlyDenied = false;
  final List<ImageSource> selectedSources = [];
  Position? position;
  XFile? photo;

  @override
  Future<Position> getCurrentPosition() async {
    if (locationError case final error?) throw error;
    return position ?? (throw StateError('No test position configured.'));
  }

  @override
  Future<XFile?> pickPhoto(ImageSource source) async {
    selectedSources.add(source);
    if (photoError case final error?) throw error;
    return photo;
  }
}

Position buildPosition() {
  return Position(
    latitude: 6.912345,
    longitude: 79.812345,
    timestamp: DateTime.utc(2026, 11, 9),
    accuracy: 8,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class ReportFormTestNavigator extends StatefulWidget {
  final FakeCitizenReportInputProvider input;

  const ReportFormTestNavigator({super.key, required this.input});

  @override
  State<ReportFormTestNavigator> createState() =>
      _ReportFormTestNavigatorState();
}

class _ReportFormTestNavigatorState extends State<ReportFormTestNavigator> {
  bool? submissionResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            submissionResult = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) =>
                    CitizenReportFormScreen(inputProvider: widget.input),
              ),
            );
            setState(() {});
          },
          child: const Text('Open report form'),
        ),
      ),
    );
  }
}
