import 'dart:collection';

import 'package:cbj_hub/domain/binding/binding_cbj_entity.dart';
import 'package:cbj_hub/domain/generic_devices/abstract_device/device_entity_abstract.dart';
import 'package:cbj_hub/domain/local_db/i_local_db_repository.dart';
import 'package:cbj_hub/domain/local_db/local_db_failures.dart';
import 'package:cbj_hub/domain/room/room_entity.dart';
import 'package:cbj_hub/domain/room/value_objects_room.dart';
import 'package:cbj_hub/domain/rooms/i_saved_rooms_repo.dart';
import 'package:cbj_hub/domain/routine/routine_cbj_entity.dart';
import 'package:cbj_hub/domain/saved_devices/i_saved_devices_repo.dart';
import 'package:cbj_hub/domain/scene/i_scene_cbj_repository.dart';
import 'package:cbj_hub/domain/scene/scene_cbj_entity.dart';
import 'package:cbj_hub/domain/scene/scene_cbj_failures.dart';
import 'package:cbj_hub/infrastructure/gen/cbj_hub_server/protoc_as_dart/cbj_hub_server.pbgrpc.dart';
import 'package:cbj_hub/injection.dart';
import 'package:cbj_hub/utils.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ISavedRoomsRepo)
class SavedRoomsRepo extends ISavedRoomsRepo {
  SavedRoomsRepo() {
    setUpAllFromDb();
  }

  static final HashMap<String, RoomEntity> _allRooms =
      HashMap<String, RoomEntity>();

  Future<void> setUpAllFromDb() async {
    /// Delay inorder for the Hive boxes to initialize
    /// In case you got the following error:
    /// "HiveError: You need to initialize Hive or provide a path to store
    /// the box."
    /// Please increase the duration
    await Future.delayed(const Duration(milliseconds: 100));
    getIt<ILocalDbRepository>().getRoomsFromDb().then((value) {
      value.fold((l) => null, (r) {
        r.forEach((element) {
          addOrUpdateRoom(element);
        });
      });
    });
  }

  @override
  Future<Map<String, RoomEntity>> getAllRooms() async {
    return _allRooms;
  }

  RoomEntity? getRoomDeviceExistIn(DeviceEntityAbstract deviceEntityAbstract) {
    final String uniqueId = deviceEntityAbstract.uniqueId.getOrCrash();
    for (final RoomEntity roomEntity in _allRooms.values) {
      if (roomEntity.roomDevicesId.getOrCrash().contains(uniqueId)) {
        return roomEntity;
      }
    }
    return null;
  }

  RoomEntity? getRoomSceneExistIn(SceneCbjEntity sceneCbj) {
    final String uniqueId = sceneCbj.uniqueId.getOrCrash();
    for (final RoomEntity roomEntity in _allRooms.values) {
      if (roomEntity.roomScenesId.getOrCrash().contains(uniqueId)) {
        return roomEntity;
      }
    }
    return null;
  }

  RoomEntity? getRoomRoutineExistIn(RoutineCbjEntity routineCbj) {
    final String uniqueId = routineCbj.uniqueId.getOrCrash();
    for (final RoomEntity roomEntity in _allRooms.values) {
      if (roomEntity.roomRoutinesId.getOrCrash().contains(uniqueId)) {
        return roomEntity;
      }
    }
    return null;
  }

  RoomEntity? getRoomBindingExistIn(BindingCbjEntity bindingCbj) {
    final String uniqueId = bindingCbj.uniqueId.getOrCrash();
    for (final RoomEntity roomEntity in _allRooms.values) {
      if (roomEntity.roomBindingsId.getOrCrash().contains(uniqueId)) {
        return roomEntity;
      }
    }
    return null;
  }

  @override
  RoomEntity addOrUpdateRoom(RoomEntity roomEntity) {
    RoomEntity newRoomEntity = roomEntity;

    final RoomEntity? roomFromAllRoomsList =
        _allRooms[roomEntity.uniqueId.getOrCrash()];

    /// TODO: Check if this should only happen in discover room
    if (roomFromAllRoomsList != null) {
      /// For devices in the room
      final List<String> allDevicesInNewRoom =
          roomEntity.roomDevicesId.getOrCrash();
      final List<String> allDevicesInExistingRoom =
          roomFromAllRoomsList.roomDevicesId.getOrCrash();

      final HashSet<String> tempAddDevicesList = HashSet<String>();
      tempAddDevicesList.addAll(allDevicesInNewRoom);
      tempAddDevicesList.addAll(allDevicesInExistingRoom);
      newRoomEntity = newRoomEntity.copyWith(
        roomDevicesId: RoomDevicesId(List.from(tempAddDevicesList)),
      );

      /// For scenes in the room
      final List<String> allScenesInNewRoom =
          roomEntity.roomScenesId.getOrCrash();
      final List<String> allScenesInExistingRoom =
          roomFromAllRoomsList.roomDevicesId.getOrCrash();

      final HashSet<String> tempAddScenesList = HashSet<String>();
      tempAddScenesList.addAll(allScenesInNewRoom);
      tempAddScenesList.addAll(allScenesInExistingRoom);
      newRoomEntity = newRoomEntity.copyWith(
        roomScenesId: RoomScenesId(List.from(tempAddScenesList)),
      );

      /// For Routines in the room
      final List<String> allRoutinesInNewRoom =
          roomEntity.roomRoutinesId.getOrCrash();
      final List<String> allRoutinesInExistingRoom =
          roomFromAllRoomsList.roomRoutinesId.getOrCrash();

      final HashSet<String> tempAddRoutinesList = HashSet<String>();
      tempAddRoutinesList.addAll(allRoutinesInNewRoom);
      tempAddRoutinesList.addAll(allRoutinesInExistingRoom);
      newRoomEntity = newRoomEntity.copyWith(
          roomRoutinesId: RoomRoutinesId(List.from(tempAddRoutinesList)));

      /// For Bindings in the room
      final List<String> allBindingsInNewRoom =
          roomEntity.roomBindingsId.getOrCrash();
      final List<String> allBindingsInExistingRoom =
          roomFromAllRoomsList.roomBindingsId.getOrCrash();

      final HashSet<String> tempAddBindingsList = HashSet<String>();
      tempAddBindingsList.addAll(allBindingsInNewRoom);
      tempAddBindingsList.addAll(allBindingsInExistingRoom);
      newRoomEntity = newRoomEntity.copyWith(
        roomBindingsId: RoomBindingsId(List.from(tempAddBindingsList)),
      );
    }

    _allRooms.addEntries([
      MapEntry<String, RoomEntity>(
        newRoomEntity.uniqueId.getOrCrash(),
        newRoomEntity,
      )
    ]);
    return newRoomEntity;
  }

  @override
  void addDeviceToRoomDiscoveredIfNotExist(DeviceEntityAbstract deviceEntity) {
    final RoomEntity? roomEntity = getRoomDeviceExistIn(deviceEntity);
    if (roomEntity != null) {
      return;
    }
    final String discoveredRoomId =
        RoomUniqueId.discoveredRoomId().getOrCrash();

    if (_allRooms[discoveredRoomId] == null) {
      _allRooms.addEntries([MapEntry(discoveredRoomId, RoomEntity.empty())]);
    }
    _allRooms[discoveredRoomId]!
        .addDeviceId(deviceEntity.uniqueId.getOrCrash());
  }

  @override
  void addSceneToRoomDiscoveredIfNotExist(SceneCbjEntity sceneCbjEntity) {
    final RoomEntity? roomEntity = getRoomSceneExistIn(sceneCbjEntity);
    if (roomEntity != null) {
      return;
    }
    final String discoveredRoomId =
        RoomUniqueId.discoveredRoomId().getOrCrash();

    if (_allRooms[discoveredRoomId] == null) {
      _allRooms.addEntries([MapEntry(discoveredRoomId, RoomEntity.empty())]);
    }
    _allRooms[discoveredRoomId]!
        .addSceneId(sceneCbjEntity.uniqueId.getOrCrash());
  }

  @override
  void addRoutineToRoomDiscoveredIfNotExist(RoutineCbjEntity routineCbjEntity) {
    final RoomEntity? roomEntity = getRoomRoutineExistIn(routineCbjEntity);
    if (roomEntity != null) {
      return;
    }
    final String discoveredRoomId =
        RoomUniqueId.discoveredRoomId().getOrCrash();

    if (_allRooms[discoveredRoomId] == null) {
      _allRooms.addEntries([MapEntry(discoveredRoomId, RoomEntity.empty())]);
    }
    _allRooms[discoveredRoomId]!
        .addRoutineId(routineCbjEntity.uniqueId.getOrCrash());
  }

  @override
  void addBindingToRoomDiscoveredIfNotExist(BindingCbjEntity bindingCbjEntity) {
    final RoomEntity? roomEntity = getRoomBindingExistIn(bindingCbjEntity);
    if (roomEntity != null) {
      return;
    }
    final String discoveredRoomId =
        RoomUniqueId.discoveredRoomId().getOrCrash();

    if (_allRooms[discoveredRoomId] == null) {
      _allRooms.addEntries([MapEntry(discoveredRoomId, RoomEntity.empty())]);
    }
    _allRooms[discoveredRoomId]!
        .addBindingId(bindingCbjEntity.uniqueId.getOrCrash());
  }

  @override
  Future<Either<LocalDbFailures, Unit>> saveAndActiveRoomToDb({
    required RoomEntity roomEntity,
  }) async {
    final String roomId = roomEntity.uniqueId.getOrCrash();

    await removeSameDevicesFromOtherRooms(roomEntity);

    List<String> newDevicesList = roomEntity.roomDevicesId.getOrCrash();

    bool newRoom = false;
    if (_allRooms[roomId] == null) {
      _allRooms.addEntries([MapEntry(roomId, roomEntity)]);
      newRoom = true;
    } else {
      newDevicesList = getOnlyWhatOnlyExistInFirsList(
        roomEntity.roomDevicesId.getOrCrash(),
        _allRooms[roomId]!.roomDevicesId.getOrCrash(),
      );

      final RoomEntity roomEntityCombinedDevices = roomEntity.copyWith(
        roomDevicesId: RoomDevicesId(
          combineNoDuplicateListOfString(
            _allRooms[roomId]!.roomDevicesId.getOrCrash(),
            roomEntity.roomDevicesId.getOrCrash(),
          ),
        ),
        roomTypes: RoomTypes(
          // Getting handled in createScenesForAllSelectedRoomTypes
          _allRooms[roomId]!.roomTypes.getOrCrash(),
        ),
        roomScenesId: RoomScenesId(
          combineNoDuplicateListOfString(
            _allRooms[roomId]!.roomScenesId.getOrCrash(),
            roomEntity.roomScenesId.getOrCrash(),
          ),
        ),
      );
      _allRooms[roomId] = roomEntityCombinedDevices;
    }
    // TODO: check if this line is not redundant
    await getIt<ISavedDevicesRepo>().saveAndActivateSmartDevicesToDb();

    await createScenesForAllSelectedRoomTypes(
      roomEntity: roomEntity,
      newRoom: newRoom,
    );

    await getIt<ISceneCbjRepository>()
        .addDevicesToMultipleScenesAreaTypeWithPreSetActions(
      devicesId: newDevicesList,
      scenesId: _allRooms[roomId]!.roomScenesId.getOrCrash(),
      areaTypes: _allRooms[roomId]!.roomTypes.getOrCrash(),
    );

    return getIt<ILocalDbRepository>().saveRoomsToDb(
      roomsList: List<RoomEntity>.from(_allRooms.values),
    );
  }

  @override
  Future<Either<LocalDbFailures, RoomEntity>>
      createScenesForAllSelectedRoomTypes({
    required RoomEntity roomEntity,
    bool newRoom = false,
  }) async {
    try {
      // To make lists mutable
      final RoomEntity roomEntityTemp = roomEntity.copyWith(
        roomTypes: RoomTypes(roomEntity.roomTypes.getOrCrash().toList()),
        roomDevicesId:
            RoomDevicesId(roomEntity.roomDevicesId.getOrCrash().toList()),
        roomScenesId:
            RoomScenesId(roomEntity.roomScenesId.getOrCrash().toList()),
        roomRoutinesId:
            RoomRoutinesId(roomEntity.roomRoutinesId.getOrCrash().toList()),
        roomBindingsId:
            RoomBindingsId(roomEntity.roomBindingsId.getOrCrash().toList()),
        roomMostUsedBy:
            RoomMostUsedBy(roomEntity.roomMostUsedBy.getOrCrash().toList()),
        roomPermissions:
            RoomPermissions(roomEntity.roomPermissions.getOrCrash().toList()),
      );

      final List<String> tempList =
          _allRooms[roomEntityTemp.uniqueId.getOrCrash()]
                  ?.roomTypes
                  .getOrCrash() ??
              [];
      final List<String> roomTypesToAdd;

      if (newRoom) {
        roomTypesToAdd = roomEntity.roomTypes.getOrCrash();
      } else {
        roomTypesToAdd = getOnlyWhatOnlyExistInFirsList(
          roomEntity.roomTypes.getOrCrash(),
          tempList,
        );
      }

      for (final String roomTypeNumber in roomTypesToAdd) {
        final AreaPurposesTypes areaPurposeType =
            AreaPurposesTypes.values[int.parse(roomTypeNumber)];

        final String areaNameEdited = areaNameCapsWithSpces(areaPurposeType);

        final Either<SceneCbjFailure, SceneCbjEntity> sceneOrFailure =
            await getIt<ISceneCbjRepository>()
                .addOrUpdateNewSceneInHubFromDevicesPropertyActionList(
          areaNameEdited,
          [],
        );
        sceneOrFailure.fold(
          (l) => logger.e('Error creating scene from room type'),
          (r) {
            //Add scene id to room
            roomEntityTemp.addSceneId(r.uniqueId.getOrCrash());
          },
        );
        _allRooms[roomEntityTemp.uniqueId.getOrCrash()] = roomEntityTemp;
      }
      return right(_allRooms[roomEntityTemp.uniqueId.getOrCrash()]!);
    } catch (e) {
      logger.e('Error setting new scene from room type\n$e');
      return left(const LocalDbFailures.unexpected());
    }
  }

  /// Remove all devices in our room from all the rooms to prevent duplicate
  Future<void> removeSameDevicesFromOtherRooms(RoomEntity roomEntity) async {
    final List<String> devicesIdInThePassedRoom =
        List.from(roomEntity.roomDevicesId.getOrCrash());
    if (devicesIdInThePassedRoom.isEmpty) {
      return;
    }

    for (RoomEntity roomEntityTemp in _allRooms.values) {
      if (roomEntityTemp.roomDevicesId.failureOrUnit != right(unit)) {
        continue;
      }
      final List<String> devicesIdInTheRoom =
          List.from(roomEntityTemp.roomDevicesId.getOrCrash());

      for (final String deviceIdInTheRoom in devicesIdInTheRoom) {
        final int indexOfDeviceId =
            devicesIdInThePassedRoom.indexOf(deviceIdInTheRoom);

        /// If device id exist in other room than delete it from that room
        if (indexOfDeviceId != -1) {
          roomEntityTemp = roomEntityTemp.copyWith(
            roomDevicesId: roomEntityTemp.deleteIdIfExist(deviceIdInTheRoom),
          );
          _allRooms[roomEntityTemp.uniqueId.getOrCrash()] = roomEntityTemp;
        }
      }
    }
  }

  List<String> combineNoDuplicateListOfString(
    List<String> devicesId,
    List<String> newDevicesId,
  ) {
    final HashSet<String> hashSetDevicesId = HashSet<String>();
    hashSetDevicesId.addAll(devicesId);
    hashSetDevicesId.addAll(newDevicesId);
    return List.from(hashSetDevicesId);
  }

  List<String> getOnlyWhatOnlyExistInFirsList(
    List<String> firstList,
    List<String> secondList,
  ) {
    final List<String> tempList = [];

    for (final String stringText in firstList) {
      if (!secondList.contains(stringText)) {
        tempList.add(stringText);
      }
    }

    return tempList;
  }

  static String areaNameCapsWithSpces(AreaPurposesTypes areaPurposeType) {
    final String tempAreaName =
        areaPurposeType.name.substring(1, areaPurposeType.name.length);
    String areaNameEdited = areaPurposeType.name.substring(0, 1).toUpperCase();
    for (int tempNum = 0; tempNum < tempAreaName.length; tempNum++) {
      final String charFromAreaType = tempAreaName[tempNum];
      if (charFromAreaType[0] == charFromAreaType[0].toUpperCase()) {
        areaNameEdited += ' ';
      }
      areaNameEdited += charFromAreaType;
    }
    return areaNameEdited;
  }

  static AreaPurposesTypes? getAreaTypeFromNameCapsWithSpcaes(
    String areaNameCapsAndSpaces,
  ) {
    String tempString = areaNameCapsAndSpaces.replaceAll(' ', '');

    tempString =
        tempString.substring(0, 1).toLowerCase() + tempString.substring(1);

    final AreaPurposesTypes areaPTemp = AreaPurposesTypes.values
        .firstWhere((element) => element.name == tempString);
    if (areaPTemp != null) {
      return areaPTemp;
    }
    return null;
  }
}
