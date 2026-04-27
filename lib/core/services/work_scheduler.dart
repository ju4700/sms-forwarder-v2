import 'package:workmanager/workmanager.dart';

import 'database_service.dart';
import 'delivery_service.dart';
import 'settings_service.dart';

const String kDrainQueueTask = 'drain-queue-task';

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? inputData) async {
    if (task == kDrainQueueTask) {
      final DeliveryService service = DeliveryService(
        databaseService: DatabaseService.instance,
        settingsService: SettingsService.instance,
      );
      await service.drainQueue();
    }
    return Future<bool>.value(true);
  });
}

class WorkScheduler {
  WorkScheduler._();

  static final WorkScheduler instance = WorkScheduler._();

  Future<void> initialize() async {
    await Workmanager().initialize(workmanagerCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'periodic-queue-drain',
      kDrainQueueTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<void> triggerOneTimeSync() async {
    await Workmanager().registerOneOffTask(
      'sync-${DateTime.now().millisecondsSinceEpoch}',
      kDrainQueueTask,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
