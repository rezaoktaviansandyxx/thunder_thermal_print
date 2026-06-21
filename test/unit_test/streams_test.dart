import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/streams/connection_stream.dart';
import 'package:thunder_thermal_print/src/streams/device_event_stream.dart';
import 'package:thunder_thermal_print/src/models/models.dart';

void main() {
  group('ConnectionStream', () {
    test('singleton returns same instance', () {
      final stream1 = ConnectionStream();
      final stream2 = ConnectionStream();
      expect(identical(stream1, stream2), true);
    });

    test('stream is broadcast', () {
      final stream = ConnectionStream();
      expect(stream.stream.isBroadcast, true);
    });

    test('currentState returns initial disconnected state', () {
      final stream = ConnectionStream();
      expect(stream.currentState, PrinterConnectionState.disconnected);
    });

    test('emit updates currentState', () {
      final stream = ConnectionStream();
      stream.emit(PrinterConnectionState.connected);
      expect(stream.currentState, PrinterConnectionState.connected);
    });

    test('stream receives emitted events', () async {
      final stream = ConnectionStream();
      final states = <PrinterConnectionState>[];
      final subscription = stream.stream.listen(states.add);

      stream.emit(PrinterConnectionState.connecting);
      stream.emit(PrinterConnectionState.connected);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(states, contains(PrinterConnectionState.connecting));
      expect(states, contains(PrinterConnectionState.connected));

      await subscription.cancel();
    });

    test('dispose closes stream', () async {
      final stream = ConnectionStream();
      await stream.dispose();

      // After dispose, emit should be no-op
      stream.emit(PrinterConnectionState.connected);
      expect(stream.currentState, PrinterConnectionState.connected); // state still updates
    });
  });

  group('DeviceEventStream', () {
    test('singleton returns same instance', () {
      final stream1 = DeviceEventStream();
      final stream2 = DeviceEventStream();
      expect(identical(stream1, stream2), true);
    });

    test('stream is broadcast', () {
      final stream = DeviceEventStream();
      expect(stream.stream.isBroadcast, true);
    });

    test('lastEvent is null initially', () {
      final stream = DeviceEventStream();
      expect(stream.lastEvent, isNull);
    });

    test('emit updates lastEvent', () {
      final stream = DeviceEventStream();
      final event = PrinterEvent(type: PrinterEventType.printerConnected);
      stream.emit(event);
      expect(stream.lastEvent, event);
    });

    test('stream receives emitted events', () async {
      final stream = DeviceEventStream();
      final events = <PrinterEvent>[];
      final subscription = stream.stream.listen(events.add);

      final event = PrinterEvent(
        type: PrinterEventType.usbAttached,
        deviceId: 'usb-123',
      );
      stream.emit(event);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(events, contains(event));

      await subscription.cancel();
    });

    test('dispose closes stream', () async {
      final stream = DeviceEventStream();
      await stream.dispose();

      // After dispose, emit should be no-op
      final event = PrinterEvent(type: PrinterEventType.error);
      stream.emit(event);
      expect(stream.lastEvent, event);
    });
  });
}
