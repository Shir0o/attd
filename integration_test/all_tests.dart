import 'package:integration_test/integration_test.dart';

import 'advanced_attendance_scenarios_test.dart' as advanced_attendance;
import 'app_test.dart' as app;
import 'auth_lifecycle_test.dart' as auth_lifecycle;
import 'cloud_sync_integration_test.dart' as cloud_sync;
import 'data_integrity_test.dart' as data_integrity;
import 'fluid_design_and_ux_test.dart' as fluid_design;
import 'quick_marking_entry_test.dart' as quick_marking;
import 'reporting_and_export_test.dart' as reporting_export;
import 'resilience_and_failure_test.dart' as resilience;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Disable runtime fetching for Google Fonts in integration tests to avoid network errors
  // GoogleFonts.config.allowRuntimeFetching = false;

  // Run all test suites inside a single executable APK
  app.main();
  advanced_attendance.main();
  auth_lifecycle.main();
  cloud_sync.main();
  data_integrity.main();
  fluid_design.main();
  quick_marking.main();
  reporting_export.main();
  resilience.main();
}
