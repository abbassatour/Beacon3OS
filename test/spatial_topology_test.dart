// test/spatial_topology_test.dart
import 'package:beacon_os/app/default_topology.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpatialTopology 3-Floor System Verification', () {
    late SpatialTopology topology;

    setUp(() {
      topology = createDefaultSpatialTopology();
    });

    test('verifies all 3 floors are registered and accessible', () {
      expect(topology.availableFloors, equals([-1, 0, 1]));
      expect(topology.minFloor, equals(-1));
      expect(topology.maxFloor, equals(1));

      expect(topology.hasFloor(-1), isTrue);
      expect(topology.hasFloor(0), isTrue);
      expect(topology.hasFloor(1), isTrue);
      expect(topology.hasFloor(2), isFalse);
      expect(topology.hasFloor(-2), isFalse);
    });

    test('verifies vertical elevator bounds for each floor level', () {
      // Floor -1 (Bottom)
      expect(topology.canDescendFrom(-1), isFalse);
      expect(topology.canAscendFrom(-1), isTrue);

      // Floor 0 (Ground)
      expect(topology.canDescendFrom(0), isTrue);
      expect(topology.canAscendFrom(0), isTrue);

      // Floor 1 (Top)
      expect(topology.canDescendFrom(1), isTrue);
      expect(topology.canAscendFrom(1), isFalse);
    });

    test('verifies each floor contains exactly the 6 core modules at matching coordinates', () {
      for (final floor in [-1, 0, 1]) {
        final nodes = topology.nodesOnFloor(floor);
        expect(nodes.length, equals(6));

        // Cockpit at origin
        final cockpit = topology.moduleAtCoordinate(SpatialCoordinate(x: 0, y: 0, floor: floor));
        expect(cockpit, isNotNull);
        expect(cockpit!.id, equals('cockpit'));

        // Focus at North (0, 1)
        final focus = topology.moduleAtCoordinate(SpatialCoordinate(x: 0, y: 1, floor: floor));
        expect(focus, isNotNull);
        expect(focus!.id, equals('focus'));

        // Perimeter at Far North (0, 2)
        final perimeter = topology.moduleAtCoordinate(SpatialCoordinate(x: 0, y: 2, floor: floor));
        expect(perimeter, isNotNull);
        expect(perimeter!.id, equals('perimeter'));

        // Comms at South (0, -1)
        final comms = topology.moduleAtCoordinate(SpatialCoordinate(x: 0, y: -1, floor: floor));
        expect(comms, isNotNull);
        expect(comms!.id, equals('comms'));

        // Vision at East (1, 0)
        final vision = topology.moduleAtCoordinate(SpatialCoordinate(x: 1, y: 0, floor: floor));
        expect(vision, isNotNull);
        expect(vision!.id, equals('vision'));

        // Agenda at West (-1, 0)
        final agenda = topology.moduleAtCoordinate(SpatialCoordinate(x: -1, y: 0, floor: floor));
        expect(agenda, isNotNull);
        expect(agenda!.id, equals('agenda'));
      }
    });

    test('verifies dynamic floor titles match architecture', () {
      // Floor -1 Titles
      expect(
        topology.titleAtCoordinate(const SpatialCoordinate(x: 0, y: 0, floor: -1)),
        equals('Mesh Hub & Connected Devices'),
      );
      expect(
        topology.titleAtCoordinate(const SpatialCoordinate(x: -1, y: 0, floor: -1)),
        equals('Archived Tasks & Notes'),
      );
      expect(
        topology.titleAtCoordinate(const SpatialCoordinate(x: 0, y: -1, floor: -1)),
        equals('Arbitrum Sepolia SOS Ledger'),
      );

      // Floor 0 Titles
      expect(
        topology.titleAtCoordinate(const SpatialCoordinate(x: 0, y: 0, floor: 0)),
        equals('Today Cockpit'),
      );
      expect(
        topology.titleAtCoordinate(const SpatialCoordinate(x: 1, y: 0, floor: 0)),
        equals('AI Vision Studio'),
      );

      // Floor 1 Titles
      expect(
        topology.titleAtCoordinate(const SpatialCoordinate(x: 0, y: 0, floor: 1)),
        equals('Core Engine & Preferences'),
      );
      expect(
        topology.titleAtCoordinate(const SpatialCoordinate(x: 0, y: 1, floor: 1)),
        equals('Focus & Alarm Tuning'),
      );
    });

    test('verifies colinear raycasting navigation on Floor -1', () {
      const originNeg1 = SpatialCoordinate(x: 0, y: 0, floor: -1);

      // Navigate North -> Focus
      final northNode = topology.findNextOccupiedInDirection(
        origin: originNeg1,
        direction: SpatialDirection.north,
      );
      expect(northNode, equals(const SpatialCoordinate(x: 0, y: 1, floor: -1)));

      // Navigate South -> Comms
      final southNode = topology.findNextOccupiedInDirection(
        origin: originNeg1,
        direction: SpatialDirection.south,
      );
      expect(southNode, equals(const SpatialCoordinate(x: 0, y: -1, floor: -1)));

      // Navigate East -> Vision
      final eastNode = topology.findNextOccupiedInDirection(
        origin: originNeg1,
        direction: SpatialDirection.east,
      );
      expect(eastNode, equals(const SpatialCoordinate(x: 1, y: 0, floor: -1)));

      // Navigate West -> Agenda
      final westNode = topology.findNextOccupiedInDirection(
        origin: originNeg1,
        direction: SpatialDirection.west,
      );
      expect(westNode, equals(const SpatialCoordinate(x: -1, y: 0, floor: -1)));
    });

    test('verifies perimeter vertical raycasting on Floor -1', () {
      const focusNeg1 = SpatialCoordinate(x: 0, y: 1, floor: -1);

      // From Focus (0, 1), navigating North lands on Perimeter (0, 2)
      final farNorthNode = topology.findNextOccupiedInDirection(
        origin: focusNeg1,
        direction: SpatialDirection.north,
      );
      expect(farNorthNode, equals(const SpatialCoordinate(x: 0, y: 2, floor: -1)));
    });
  });
}