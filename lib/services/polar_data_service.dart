import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/station.dart';
import '../models/inventory_item.dart';
import '../models/personnel.dart';
import '../models/resupply_cycle.dart';
import '../models/cargo_item.dart';
import '../models/alert_item.dart';
import '../models/comms_message.dart';
import '../models/call_booking.dart';
import '../models/user_role.dart';
import '../models/inventory_audit_log.dart';
import '../models/resource_request.dart';
import '../models/family_invite.dart';
import '../core/utils/watney_calculator.dart';
import '../core/utils/validators.dart';
import '../models/ncpor_reading.dart';
import 'ncpor_data_source.dart';
import 'supabase_repository.dart';

/// Central Polar Data Service providing state & CRUD for AROHA
class PolarDataService extends ChangeNotifier {
  // In-memory data store
  final List<Station> _stations = [];
  final List<InventoryItem> _inventory = [];
  final List<Personnel> _personnel = [];
  final List<ResupplyCycle> _resupplyCycles = [];
  final List<AlertItem> _alerts = [];
  final List<CommsMessage> _messages = [];
  final List<CallBooking> _callBookings = [];

  final List<InventoryAuditLog> _auditLogs = [];
  final List<ResourceRequest> _resourceRequests = [];
  final List<FamilyInvite> _familyInvites = [];

  final SupabaseRepository _repo = SupabaseRepository();

  // Live telemetry source: National Polar Data Center (data.ncpor.res.in).
  final NporDataSource _ncpor = NporDataSource();

  /// stationId → most recent portal reading, kept even when a fetch fails
  /// so the UI can report *why* it is showing mock values.
  final Map<String, NporReading> _liveReadings = {};
  Timer? _ncporTimer;
  bool _ncporSyncing = false;

  String _selectedStationId = 'maitri';

  // Getters
  List<Station> get stations => List.unmodifiable(_stations);
  List<InventoryItem> get inventory => List.unmodifiable(_inventory);
  List<Personnel> get personnel => List.unmodifiable(_personnel);
  List<ResupplyCycle> get resupplyCycles => List.unmodifiable(_resupplyCycles);
  List<AlertItem> get alerts => List.unmodifiable(_alerts);
  List<CommsMessage> get messages => List.unmodifiable(_messages);
  List<CallBooking> get callBookings => List.unmodifiable(_callBookings);
  List<InventoryAuditLog> get auditLogs => List.unmodifiable(_auditLogs);
  List<ResourceRequest> get resourceRequests =>
      List.unmodifiable(_resourceRequests);
  List<FamilyInvite> get familyInvites => List.unmodifiable(_familyInvites);
  String get selectedStationId => _selectedStationId;

  // --- NPDC live telemetry ---

  /// True while a portal poll is in flight.
  bool get ncporSyncing => _ncporSyncing;

  NporReading? readingFor(String stationId) => _liveReadings[stationId];

  NporReading? get selectedStationReading => _liveReadings[_selectedStationId];

  /// Never claims LIVE for mock or lagged data: unattempted → idle,
  /// failed → unavailable, parsed-but-old → stale.
  NporTelemetryStatus statusFor(String stationId) {
    if (_ncporSyncing && !_liveReadings.containsKey(stationId)) {
      return NporTelemetryStatus.syncing;
    }
    final reading = _liveReadings[stationId];
    if (reading == null) return NporTelemetryStatus.idle;
    return reading.status;
  }

  NporTelemetryStatus get selectedStationStatus =>
      statusFor(_selectedStationId);

  Station get selectedStation {
    if (_stations.isEmpty) {
      return Station(
        id: 'unknown',
        name: 'No Station Available',
        code: 'NONE',
        location: 'Unknown',
        coordinates: '0°0′0″S 0°0′0″E',
        status: 'active',
        lastContact: DateTime.now(),
        powerLevel: 0,
        temperature: 0,
        windSpeed: 0,
        satLinkSignal: 0,
        sectorLiveCamUrl: '',
        activePersonnelCount: 0,
        nextResupplyDate: DateTime.now(),
      );
    }
    return _stations.firstWhere(
      (s) => s.id == _selectedStationId,
      orElse: () => _stations.first,
    );
  }

  /// Returns stations accessible by the given user
  List<Station> getVisibleStations(UserProfile? user) {
    if (user == null) return [];
    if (user.role == UserRole.hqAdmin) return stations;
    if (user.linkedStationId != null) {
      return _stations.where((s) => s.id == user.linkedStationId).toList();
    }
    return [];
  }

  /// Returns inventory accessible by the given user
  List<InventoryItem> getVisibleInventory(UserProfile? user) {
    if (user == null) return [];
    if (user.role == UserRole.hqAdmin) return inventory;
    if (user.linkedStationId != null) {
      return _inventory
          .where((i) => i.stationId == user.linkedStationId)
          .toList();
    }
    return [];
  }

  /// Returns comms messages filtered for the given user.
  /// Family sessions never receive station traffic — invite scope only.
  List<CommsMessage> getMessagesForUser(UserProfile? user) {
    if (user == null) return [];
    if (user.role == UserRole.familyMember) return [];
    if (user.role == UserRole.hqAdmin) {
      return List.unmodifiable(_messages);
    }
    // Station staff: messages for their station or directed to them
    return _messages.where((m) {
      if (m.senderId == user.uid || m.recipientId == user.uid) return true;
      if (user.linkedPersonId != null &&
          (m.senderId == user.linkedPersonId ||
              m.recipientId == user.linkedPersonId)) {
        return true;
      }
      if (m.stationId == user.linkedStationId) return true;
      // Cross-station messages involving user's station
      if (m.recipientStationId == user.linkedStationId) return true;
      if (m.recipientId == user.linkedStationId) return true;
      return false;
    }).toList();
  }

  List<InventoryItem> get selectedStationInventory {
    return _inventory.where((i) => i.stationId == _selectedStationId).toList();
  }

  List<Personnel> get selectedStationPersonnel {
    return _personnel.where((p) => p.stationId == _selectedStationId).toList();
  }

  List<AlertItem> get selectedStationAlerts {
    return _alerts.where((a) => a.stationId == _selectedStationId).toList();
  }

  List<AlertItem> get activeCriticalAlerts {
    return _alerts
        .where((a) => !a.resolved && a.severity == 'critical')
        .toList();
  }

  List<AlertItem> get activeWarningAlerts {
    return _alerts
        .where((a) => !a.resolved && a.severity == 'warning')
        .toList();
  }

  PolarDataService() {
    _seedInitialData();
    recalculateAllWatneyAlerts();
    unawaited(syncFromCloud());
  }

  /// Cloud sync: pulls backend state when present, otherwise pushes the
  /// local seeds as first-run bootstrap. Retries briefly because the
  /// Supabase init races provider creation at startup. Offline-safe.
  Future<void> syncFromCloud() async {
    for (var attempt = 0; attempt < 6 && !_repo.isAvailable; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
    }
    try {
      if (!_repo.isAvailable) return;
      final cloudStations = await _repo.fetchStations();
      if (cloudStations.isEmpty) {
        await _repo.upsertStations(_stations);
        await _repo.upsertInventoryItems(_inventory);
        await _repo.upsertPersonnel(_personnel);
        await _repo.upsertCycles(_resupplyCycles);
        await _repo.upsertManualAlerts(_alerts);
        await _repo.upsertMessages(_messages);
        await _repo.upsertBookings(_callBookings);
        await _repo.upsertResourceRequests(_resourceRequests);
        await _repo.upsertInvites(_familyInvites);
      } else {
        // Pull branch: only replace a list when the cloud actually has
        // rows for it — never wipe local seeds with empty tables.
        _stations
          ..clear()
          ..addAll(cloudStations);
        final cloudInventory = await _repo.fetchInventory();
        if (cloudInventory.isNotEmpty) {
          _inventory
            ..clear()
            ..addAll(cloudInventory);
        }
        final cloudPersonnel = await _repo.fetchPersonnel();
        if (cloudPersonnel.isNotEmpty) {
          _personnel
            ..clear()
            ..addAll(cloudPersonnel);
        }
        final cloudCycles = await _repo.fetchCycles();
        if (cloudCycles.isNotEmpty) {
          _resupplyCycles
            ..clear()
            ..addAll(cloudCycles);
        }
        final manualAlerts = await _repo.fetchManualAlerts();
        _alerts.removeWhere((a) => !a.id.startsWith('watney_'));
        _alerts.addAll(
          manualAlerts.where((a) => !_alerts.any((e) => e.id == a.id)),
        );
        final msgs = await _repo.fetchMessages();
        if (msgs.isNotEmpty) {
          _messages
            ..clear()
            ..addAll(msgs);
        }
        final bookings = await _repo.fetchBookings();
        if (bookings.isNotEmpty) {
          _callBookings
            ..clear()
            ..addAll(bookings);
        }
        final cloudRequests = await _repo.fetchResourceRequests();
        if (cloudRequests.isNotEmpty) {
          _resourceRequests
            ..clear()
            ..addAll(cloudRequests);
        }
        final cloudInvites = await _repo.fetchInvites();
        if (cloudInvites.isNotEmpty) {
          _familyInvites
            ..clear()
            ..addAll(cloudInvites);
        }
        final cloudLogs = await _repo.fetchAuditLogs();
        if (cloudLogs.isNotEmpty) {
          _auditLogs
            ..clear()
            ..addAll(cloudLogs);
        }
        _reapplyLiveReadings();
        recalculateAllWatneyAlerts();
        notifyListeners();
      }
      _repo.subscribeToRemote((_) => _pullRemoteUpdates());
    } catch (_) {}
  }

  /// Merge live inserts/updates from other clients (alerts, messages,
  /// resource requests). New ids only — never overwrites local edits
  /// except request status updates, which are HQ-moderated by design.
  Future<void> _pullRemoteUpdates() async {
    try {
      if (!_repo.isAvailable) return;
      var changed = false;
      for (final a in await _repo.fetchManualAlerts()) {
        if (!_alerts.any((e) => e.id == a.id)) {
          _alerts.insert(0, a);
          changed = true;
        }
      }
      for (final m in await _repo.fetchMessages()) {
        if (!_messages.any((e) => e.id == m.id)) {
          _messages.add(m);
          changed = true;
        }
      }
      if (changed) {
        _messages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      }
      for (final r in await _repo.fetchResourceRequests()) {
        final idx = _resourceRequests.indexWhere((e) => e.id == r.id);
        if (idx == -1) {
          _resourceRequests.insert(0, r);
          changed = true;
        } else if (_resourceRequests[idx].status != r.status ||
            _resourceRequests[idx].responseNotes != r.responseNotes) {
          _resourceRequests[idx] = r;
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  void selectStation(String stationId) {
    if (_selectedStationId != stationId) {
      _selectedStationId = stationId;
      notifyListeners();
    }
  }

  // --- NPDC Live Telemetry ---

  /// Polls the National Polar Data Center portal and folds the real
  /// measurements over the seeded temperature/wind values.
  ///
  /// Only temperature and wind come from NPDC — power level and sat-link
  /// have no portal equivalent and stay local. Never throws: a failed
  /// fetch records an error on the reading so the UI can label the values
  /// as mock instead of presenting them as live.
  Future<void> refreshNporTelemetry() async {
    if (_ncporSyncing) return; // don't stack polls
    _ncporSyncing = true;
    notifyListeners();

    for (final station in List<Station>.from(_stations)) {
      if (!NporDataSource.supports(station.id)) continue;
      final reading = await _ncpor.fetchReading(station.id);
      _liveReadings[station.id] = reading;
      if (reading.hasData) _applyReading(station.id, reading);
    }

    _ncporSyncing = false;
    notifyListeners();
  }

  /// Kicks off the first poll and a repeating cadence.
  ///
  /// Deliberately *not* called from the constructor: unit tests build a
  /// bare `PolarDataService()` and must not open sockets or leave a
  /// periodic timer running. Only `main.dart` starts polling.
  void startNporPolling({Duration interval = const Duration(minutes: 15)}) {
    _ncporTimer?.cancel();
    _ncporTimer = Timer.periodic(interval, (_) => refreshNporTelemetry());
    unawaited(refreshNporTelemetry());
  }

  void _applyReading(String stationId, NporReading reading) {
    final index = _stations.indexWhere((s) => s.id == stationId);
    if (index == -1) return;
    final current = _stations[index];
    _stations[index] = current.copyWith(
      temperature: reading.temperatureC ?? current.temperature,
      windSpeed: reading.windSpeedKnots ?? current.windSpeed,
      // The observation time *is* the last contact with that station.
      lastContact: reading.observedAt ?? current.lastContact,
    );
  }

  /// Re-folds cached readings after a cloud pull replaces `_stations`, so
  /// backend rows cannot silently revert telemetry to the seed values.
  void _reapplyLiveReadings() {
    for (final entry in _liveReadings.entries) {
      if (entry.value.hasData) _applyReading(entry.key, entry.value);
    }
  }

  @override
  void dispose() {
    _ncporTimer?.cancel();
    super.dispose();
  }

  // --- Inventory Operations ---

  bool addInventoryItem(InventoryItem item, {UserProfile? user}) {
    // Permission check
    if (user != null && !user.canEditStation(item.stationId)) {
      return false;
    }
    // Duplicate ID prevention
    if (_inventory.any((i) => i.id == item.id)) {
      return false;
    }

    _inventory.add(item);
    _auditLogs.insert(
      0,
      InventoryAuditLog(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        itemId: item.id,
        itemName: item.name,
        stationId: item.stationId,
        action: 'create',
        previousQuantity: 0.0,
        newQuantity: item.currentQuantity,
        performedByUserId: user?.uid ?? 'system',
        performedByUserName: user?.name ?? 'System Admin',
        timestamp: DateTime.now(),
        notes: 'Item created in catalog',
      ),
    );
    recalculateAllWatneyAlerts();
    notifyListeners();
    unawaited(_repo.upsertInventoryItem(item));
    unawaited(_repo.insertAuditLog(_auditLogs.first));
    return true;
  }

  bool updateInventoryItem(InventoryItem updatedItem, {UserProfile? user}) {
    if (user != null && !user.canEditStation(updatedItem.stationId)) {
      return false;
    }
    final index = _inventory.indexWhere((i) => i.id == updatedItem.id);
    if (index != -1) {
      final old = _inventory[index];
      _inventory[index] = updatedItem;
      _auditLogs.insert(
        0,
        InventoryAuditLog(
          id: 'log_${DateTime.now().millisecondsSinceEpoch}',
          itemId: updatedItem.id,
          itemName: updatedItem.name,
          stationId: updatedItem.stationId,
          action: 'update',
          previousQuantity: old.currentQuantity,
          newQuantity: updatedItem.currentQuantity,
          performedByUserId: user?.uid ?? 'system',
          performedByUserName: user?.name ?? 'Station Staff',
          timestamp: DateTime.now(),
          notes: 'Item details updated',
        ),
      );
      recalculateAllWatneyAlerts();
      notifyListeners();
      unawaited(_repo.upsertInventoryItem(updatedItem));
      unawaited(_repo.insertAuditLog(_auditLogs.first));
      return true;
    }
    return false;
  }

  bool logConsumption(
    String itemId,
    double consumedAmount, {
    UserProfile? user,
  }) {
    final index = _inventory.indexWhere((i) => i.id == itemId);
    if (index == -1) return false;

    final old = _inventory[index];
    if (user != null && !user.canEditStation(old.stationId)) {
      return false;
    }

    // Input validation
    final err = Validators.validateConsumption(
      consumedAmount,
      old.currentQuantity,
    );
    if (err != null) return false;

    final newQty = (old.currentQuantity - consumedAmount).clamp(0.0, 999999.0);
    _inventory[index] = old.copyWith(
      currentQuantity: newQty,
      lastUpdated: DateTime.now(),
    );

    _auditLogs.insert(
      0,
      InventoryAuditLog(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        itemId: old.id,
        itemName: old.name,
        stationId: old.stationId,
        action: 'consumption',
        previousQuantity: old.currentQuantity,
        newQuantity: newQty,
        performedByUserId: user?.uid ?? 'system',
        performedByUserName: user?.name ?? 'Station Staff',
        timestamp: DateTime.now(),
        notes:
            'Logged consumption of ${consumedAmount.toStringAsFixed(1)} ${old.unit}',
      ),
    );

    recalculateAllWatneyAlerts();
    notifyListeners();
    unawaited(_repo.upsertInventoryItem(_inventory[index]));
    unawaited(_repo.insertAuditLog(_auditLogs.first));
    return true;
  }

  void deleteInventoryItem(String itemId, {UserProfile? user}) {
    final index = _inventory.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final item = _inventory[index];
    if (user != null && !user.canEditStation(item.stationId)) {
      return;
    }
    _inventory.removeAt(index);
    _alerts.removeWhere((a) => a.itemId == itemId);
    _auditLogs.insert(
      0,
      InventoryAuditLog(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        itemId: itemId,
        itemName: item.name,
        stationId: item.stationId,
        action: 'delete',
        previousQuantity: item.currentQuantity,
        newQuantity: 0.0,
        performedByUserId: user?.uid ?? 'system',
        performedByUserName: user?.name ?? 'System Admin',
        timestamp: DateTime.now(),
        notes: 'Item removed from inventory',
      ),
    );
    notifyListeners();
    unawaited(_repo.deleteInventoryItem(itemId));
    unawaited(_repo.insertAuditLog(_auditLogs.first));
  }

  // --- Watney Alert Recalculation Engine ---

  void recalculateAllWatneyAlerts() {
    // Retain non-watney manual alerts
    _alerts.removeWhere((a) => a.id.startsWith('watney_'));

    for (final station in _stations) {
      final stationItems = _inventory
          .where((i) => i.stationId == station.id)
          .toList();
      final watneyAlerts = WatneyCalculator.generateStockAlerts(
        items: stationItems,
        daysUntilResupply: station.daysUntilResupply,
        stationId: station.id,
      );
      _alerts.insertAll(0, watneyAlerts);
    }
  }

  // --- Personnel Operations ---

  bool addPersonnel(Personnel person, {UserProfile? user}) {
    if (user != null && !user.canEditStation(person.stationId)) {
      return false;
    }
    // Duplicate prevention
    if (_personnel.any((p) => p.id == person.id)) {
      return false;
    }
    _personnel.add(person);
    _updateStationPersonnelCounts();
    notifyListeners();
    unawaited(_repo.upsertPerson(person));
    return true;
  }

  void updatePersonnel(Personnel updated, {UserProfile? user}) {
    if (user != null && !user.canEditStation(updated.stationId)) {
      return;
    }
    final index = _personnel.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _personnel[index] = updated;
      _updateStationPersonnelCounts();
      notifyListeners();
      unawaited(_repo.upsertPerson(updated));
    }
  }

  void deletePersonnel(String id, {UserProfile? user}) {
    final index = _personnel.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final person = _personnel[index];
    if (user != null && !user.canEditStation(person.stationId)) {
      return;
    }
    _personnel.removeAt(index);
    _updateStationPersonnelCounts();
    notifyListeners();
    unawaited(_repo.deletePerson(id));
  }

  void _updateStationPersonnelCounts() {
    for (int i = 0; i < _stations.length; i++) {
      final count = _personnel
          .where(
            (p) => p.stationId == _stations[i].id && p.status == 'on-station',
          )
          .length;
      _stations[i] = _stations[i].copyWith(activePersonnelCount: count);
    }
  }

  // --- Cargo & Resupply Operations ---

  bool addCargoItem(String cycleId, CargoItem cargo, {UserProfile? user}) {
    final cycleIdx = _resupplyCycles.indexWhere((c) => c.id == cycleId);
    if (cycleIdx == -1) return false;
    final cycle = _resupplyCycles[cycleIdx];
    if (user != null && !user.canEditStation(cycle.stationId)) {
      return false;
    }
    if (cycle.cargoItems.any((i) => i.id == cargo.id)) {
      return false;
    }
    final updatedCargo = List<CargoItem>.from(cycle.cargoItems)..add(cargo);
    _resupplyCycles[cycleIdx] = cycle.copyWith(cargoItems: updatedCargo);
    notifyListeners();
    unawaited(_repo.upsertCargoItem(cargo));
    return true;
  }

  bool updateCargoStatus(
    String cycleId,
    String cargoId,
    String newStatus, {
    UserProfile? user,
  }) {
    final cycleIdx = _resupplyCycles.indexWhere((c) => c.id == cycleId);
    if (cycleIdx == -1) return false;
    final cycle = _resupplyCycles[cycleIdx];
    if (user != null && !user.canEditStation(cycle.stationId)) {
      return false;
    }
    final itemIdx = cycle.cargoItems.indexWhere((i) => i.id == cargoId);
    if (itemIdx != -1) {
      final updatedList = List<CargoItem>.from(cycle.cargoItems);
      updatedList[itemIdx] = updatedList[itemIdx].copyWith(status: newStatus);
      _resupplyCycles[cycleIdx] = cycle.copyWith(cargoItems: updatedList);
      notifyListeners();
      unawaited(_repo.upsertCargoItem(updatedList[itemIdx]));
      return true;
    }
    return false;
  }

  // --- Comms & Messages ---

  void sendMessage(CommsMessage message, {UserProfile? user}) {
    if (user != null && !user.hasPermission(Permission.sendMessages)) {
      return;
    }
    _messages.insert(0, message);
    notifyListeners();
    unawaited(_repo.upsertMessage(message));
  }

  void markMessageRead(String messageId) {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(read: true);
      notifyListeners();
      unawaited(_repo.upsertMessage(_messages[idx]));
    }
  }

  // --- Call Bookings ---

  bool bookCallSlot(CallBooking booking, {UserProfile? user}) {
    if (user != null && !user.canEditStation(booking.stationId)) {
      return false;
    }
    _callBookings.insert(0, booking);
    notifyListeners();
    unawaited(_repo.upsertBooking(booking));
    return true;
  }

  bool updateBookingStatus(
    String bookingId,
    String status, {
    UserProfile? user,
  }) {
    final idx = _callBookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) return false;
    if (user != null && !user.canEditStation(_callBookings[idx].stationId)) {
      return false;
    }
    _callBookings[idx] = _callBookings[idx].copyWith(status: status);
    notifyListeners();
    unawaited(_repo.upsertBooking(_callBookings[idx]));
    return true;
  }

  // --- Cross-Station Resource Requests ---

  /// Get resource requests relevant to a station (sent or received)
  List<ResourceRequest> getResourceRequestsForStation(String? stationId) {
    if (stationId == null) return List.unmodifiable(_resourceRequests);
    return _resourceRequests
        .where(
          (r) => r.fromStationId == stationId || r.toStationId == stationId,
        )
        .toList();
  }

  /// Create a new inter-station resource request.
  /// The requester must hold edit rights on the FROM station.
  bool createResourceRequest(ResourceRequest request, {UserProfile? user}) {
    if (user != null && !user.canEditStation(request.fromStationId)) {
      return false;
    }
    _resourceRequests.insert(0, request);
    notifyListeners();
    unawaited(_repo.upsertResourceRequest(request));
    return true;
  }

  /// Respond to a resource request (approve/deny).
  /// The responder must hold edit rights on the TO station (HQ qualifies).
  bool respondToResourceRequest(
    String requestId, {
    required String status,
    String? responseNotes,
    String? respondedByName,
    UserProfile? user,
  }) {
    final idx = _resourceRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;
    if (user != null &&
        !user.canEditStation(_resourceRequests[idx].toStationId)) {
      return false;
    }
    _resourceRequests[idx] = _resourceRequests[idx].copyWith(
      status: status,
      responseNotes: responseNotes,
      respondedByName: respondedByName,
      respondedAt: DateTime.now(),
    );
    notifyListeners();
    unawaited(_repo.upsertResourceRequest(_resourceRequests[idx]));
    return true;
  }

  /// Get station name by ID (helper for cross-station UI)
  String getStationName(String stationId) {
    if (_stations.isEmpty) return 'Unknown Station';
    final match = _stations.where((s) => s.id == stationId);
    return match.isNotEmpty ? match.first.name : _stations.first.name;
  }

  /// Get all station IDs except the given one (for recipient selection)
  List<Station> getOtherStations(String? excludeStationId) {
    if (excludeStationId == null) return stations;
    return _stations.where((s) => s.id != excludeStationId).toList();
  }

  // --- Family Call Invites (invite-only, own-slot scope) ---

  /// Look up an invite by its shareable code (case-insensitive).
  FamilyInvite? getInviteByCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final invite in _familyInvites) {
      if (invite.inviteCode.toUpperCase() == normalized) return invite;
    }
    return null;
  }

  FamilyInvite? getInviteForBooking(String bookingId) {
    for (final invite in _familyInvites) {
      if (invite.bookingId == bookingId) return invite;
    }
    return null;
  }

  CallBooking? getBookingById(String bookingId) {
    for (final booking in _callBookings) {
      if (booking.id == bookingId) return booking;
    }
    return null;
  }

  /// Create a family invite for a call booking. Only station editors or HQ,
  /// and only while the booking is still joinable (booked/live).
  /// Returns null when not permitted or an invite already exists.
  FamilyInvite? createFamilyInvite({
    required String bookingId,
    required UserProfile createdBy,
  }) {
    final bookingIdx = _callBookings.indexWhere((b) => b.id == bookingId);
    if (bookingIdx == -1) return null;
    final booking = _callBookings[bookingIdx];
    if (!createdBy.canEditStation(booking.stationId)) return null;
    if (booking.status != 'booked' && booking.status != 'live') return null;
    final existing = getInviteForBooking(bookingId);
    if (existing != null) return existing;

    final invite = FamilyInvite(
      id: 'fam_${DateTime.now().millisecondsSinceEpoch}',
      inviteCode: FamilyInvite.makeCode(booking.stationId),
      bookingId: booking.id,
      stationId: booking.stationId,
      personId: booking.personId,
      personName: booking.personName,
      familyContactName: booking.familyContactName,
      createdByUserId: createdBy.uid,
      createdByName: createdBy.name,
      createdAt: DateTime.now(),
    );
    _familyInvites.insert(0, invite);
    _callBookings[bookingIdx] = booking.copyWith(inviteCode: invite.inviteCode);
    notifyListeners();
    unawaited(_repo.upsertInvite(invite));
    unawaited(_repo.upsertBooking(_callBookings[bookingIdx]));
    return invite;
  }

  /// Record family consent + briefing acknowledgement, mirrored onto the
  /// booking so HQ has a single audit trail. Requires the entry
  /// disclaimer to be signed first. Returns false if unknown id.
  bool confirmFamilyConsent(String inviteId) {
    final idx = _familyInvites.indexWhere((i) => i.id == inviteId);
    if (idx == -1) return false;
    if (!_familyInvites[idx].disclaimerAccepted) return false;
    _familyInvites[idx] = _familyInvites[idx].copyWith(
      consentGiven: true,
      consentAt: DateTime.now(),
      briefingAcked: true,
    );
    final bookingIdx = _callBookings.indexWhere(
      (b) => b.id == _familyInvites[idx].bookingId,
    );
    if (bookingIdx != -1) {
      _callBookings[bookingIdx] = _callBookings[bookingIdx].copyWith(
        familyConsentGiven: true,
        briefingAcked: true,
      );
      unawaited(_repo.upsertBooking(_callBookings[bookingIdx]));
    }
    notifyListeners();
    unawaited(_repo.upsertInvite(_familyInvites[idx]));
    return true;
  }

  /// Family entry disclaimer — must be signed BEFORE the portal unlocks.
  /// Any non-empty typed signature + the read-checkbox is accepted; the
  /// typed name is recorded for audit. Returns false on empty/missing tick.
  bool acceptFamilyDisclaimer({
    required String inviteId,
    required String signedName,
    required bool readConfirmed,
  }) {
    final idx = _familyInvites.indexWhere((i) => i.id == inviteId);
    if (idx == -1 || !readConfirmed) return false;
    if (signedName.trim().isEmpty) return false;
    final invite = _familyInvites[idx];
    _familyInvites[idx] = invite.copyWith(
      disclaimerAccepted: true,
      disclaimerSignedName: signedName.trim(),
      disclaimerSignedAt: DateTime.now(),
    );
    notifyListeners();
    unawaited(_repo.upsertInvite(_familyInvites[idx]));
    return true;
  }

  /// Crew undertaking — signed station-side before joining a call.
  /// Station staff may only sign the booking linked to their own crew
  /// record; HQ admins may countersign (oversight). The typed signatory
  /// name is recorded. Joinable bookings only.
  bool signCrewDisclaimer({
    required String bookingId,
    required UserProfile signedBy,
    required String signatoryName,
    required bool readConfirmed,
  }) {
    final idx = _callBookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1 || !readConfirmed) return false;
    final booking = _callBookings[idx];
    if (!signedBy.canEditStation(booking.stationId)) return false;
    if (booking.status != 'booked' && booking.status != 'live') return false;
    if (signedBy.role == UserRole.stationStaff &&
        signedBy.linkedPersonId != booking.personId) {
      return false;
    }
    if (signatoryName.trim().isEmpty) return false;
    _callBookings[idx] = _callBookings[idx].copyWith(
      crewDisclaimerSigned: true,
      crewDisclaimerBy: signatoryName.trim(),
      crewDisclaimerAt: DateTime.now(),
    );
    notifyListeners();
    unawaited(_repo.upsertBooking(_callBookings[idx]));
    return true;
  }

  // --- Alerts Operations ---

  bool resolveAlert(String alertId, {UserProfile? user}) {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      final alert = _alerts[idx];
      if (user != null) {
        if (!user.hasPermission(Permission.resolveAlerts)) return false;
        if (!user.canEditStation(alert.stationId)) return false;
      }
      _alerts[idx] = alert.copyWith(resolved: true);
      notifyListeners();
      unawaited(_repo.upsertAlert(_alerts[idx]));
      return true;
    }
    return false;
  }

  void createManualAlert(AlertItem alert) {
    _alerts.insert(0, alert);
    notifyListeners();
    unawaited(_repo.upsertAlert(alert));
  }

  // --- Initial Mock Data Generator ---

  void _seedInitialData() {
    // 1. Stations (Maitri, Bharati, Himadri)
    _stations.addAll([
      Station(
        id: 'maitri',
        name: 'Maitri Station',
        code: 'MTR-01',
        location: 'Schirmacher Oasis, Queen Maud Land, East Antarctica',
        coordinates: '70°45′57″S 11°44′09″E',
        status: 'active',
        lastContact: DateTime.now().subtract(const Duration(minutes: 2)),
        powerLevel: 88,
        temperature: -24.8,
        windSpeed: 22.4,
        satLinkSignal: 99.8,
        sectorLiveCamUrl:
            'https://images.unsplash.com/photo-1517411032315-54ef2cb783bb?auto=format&fit=crop&w=800&q=80',
        activePersonnelCount: 24,
        nextResupplyDate: DateTime.now().add(const Duration(days: 114)),
      ),
      Station(
        id: 'bharati',
        name: 'Bharati Station',
        code: 'BHR-02',
        location: 'Larsemann Hills, East Antarctica',
        coordinates: '69°24′28″S 76°11′14″E',
        status: 'active',
        lastContact: DateTime.now().subtract(const Duration(minutes: 5)),
        powerLevel: 94,
        temperature: -18.2,
        windSpeed: 15.1,
        satLinkSignal: 98.2,
        sectorLiveCamUrl:
            'https://images.unsplash.com/photo-1483921020237-2ff51e8e4b22?auto=format&fit=crop&w=800&q=80',
        activePersonnelCount: 18,
        nextResupplyDate: DateTime.now().add(const Duration(days: 82)),
      ),
      Station(
        id: 'himadri',
        name: 'Himadri Arctic Station',
        code: 'HMD-03',
        location: 'Ny-Ålesund, Spitsbergen, Svalbard (Arctic)',
        coordinates: '78°55′00″N 11°56′00″E',
        status: 'low-connectivity',
        lastContact: DateTime.now().subtract(const Duration(minutes: 42)),
        powerLevel: 72,
        temperature: -12.4,
        windSpeed: 38.6,
        satLinkSignal: 64.5,
        sectorLiveCamUrl:
            'https://images.unsplash.com/photo-1548195667-1d329af0a472?auto=format&fit=crop&w=800&q=80',
        activePersonnelCount: 8,
        nextResupplyDate: DateTime.now().add(const Duration(days: 45)),
      ),
    ]);

    // 2. Inventory Items
    _inventory.addAll([
      // Maitri Inventory
      InventoryItem(
        id: 'inv_mtr_diesel',
        stationId: 'maitri',
        name: 'Polar Special High-Grade Diesel (D-A)',
        category: 'fuel',
        currentQuantity: 4200.0,
        unit: 'liters',
        dailyConsumptionRate:
            48.0, // 4200 / 48 = 87.5 days -> resupply in 114 days -> Watney ALERT
        reorderThreshold: 2000.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 3)),
        storageLocation: 'Primary Tank Farm B-4',
        notes: 'Main power generator feed. Tank insulated.',
      ),
      InventoryItem(
        id: 'inv_mtr_atf',
        stationId: 'maitri',
        name: 'Aviation Turbine Fuel (Jet A-1)',
        category: 'fuel',
        currentQuantity: 7800.0,
        unit: 'liters',
        dailyConsumptionRate: 25.0,
        reorderThreshold: 1500.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
        storageLocation: 'Helipad Fuel Depot',
        notes: 'Dedicated for ALCI Ilyushin-76 & Chetak helicopters',
      ),
      InventoryItem(
        id: 'inv_mtr_rations',
        stationId: 'maitri',
        name: 'Freeze-Dried Expedition Rations (Pack A)',
        category: 'food',
        currentQuantity: 1450.0,
        unit: 'ration boxes',
        dailyConsumptionRate: 8.5, // 170 days -> nominal
        reorderThreshold: 400.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
        storageLocation: 'Thermal Food Module #2',
        notes: 'High-calorie cold-climate balanced meals',
      ),
      InventoryItem(
        id: 'inv_mtr_medkits',
        stationId: 'maitri',
        name: 'Trauma & Hypothermia Treatment Kits',
        category: 'medical',
        currentQuantity: 34.0,
        unit: 'kits',
        dailyConsumptionRate: 0.15,
        reorderThreshold: 15.0,
        lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
        storageLocation: 'Infirmary ICU Unit',
        notes: 'Contains automated external defibrillator & plasma substitutes',
      ),
      InventoryItem(
        id: 'inv_mtr_oxygen',
        stationId: 'maitri',
        name: 'Medical Grade Oxygen Cylinders (50L)',
        category: 'medical',
        currentQuantity: 8.0, // Critical threshold!
        unit: 'cylinders',
        dailyConsumptionRate: 0.1,
        reorderThreshold: 12.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 12)),
        storageLocation: 'Medical Gas Locker',
        notes: '3 units under service pressure test',
      ),
      InventoryItem(
        id: 'inv_mtr_spares',
        stationId: 'maitri',
        name: 'Cummins Diesel Generator Injector Nozzles',
        category: 'spare-parts',
        currentQuantity: 18.0,
        unit: 'units',
        dailyConsumptionRate: 0.08,
        reorderThreshold: 6.0,
        lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
        storageLocation: 'Workshop Rack 3C',
      ),

      // Bharati Inventory
      InventoryItem(
        id: 'inv_bhr_diesel',
        stationId: 'bharati',
        name: 'Ultra-Low Sulfur Antarctic Diesel',
        category: 'fuel',
        currentQuantity: 8600.0,
        unit: 'liters',
        dailyConsumptionRate:
            52.0, // 165 days -> resupply in 82 days -> nominal
        reorderThreshold: 2500.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 4)),
        storageLocation: 'Central Energy Core Tank',
      ),
      InventoryItem(
        id: 'inv_bhr_food',
        stationId: 'bharati',
        name: 'Sterilized Protein & Grains Reserve',
        category: 'food',
        currentQuantity: 920.0,
        unit: 'kg',
        dailyConsumptionRate: 6.0,
        reorderThreshold: 200.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
        storageLocation: 'Hydroponics & Pantry #1',
      ),
      InventoryItem(
        id: 'inv_bhr_filters',
        stationId: 'bharati',
        name: 'RO Desalination Membrane Filters',
        category: 'spare-parts',
        currentQuantity: 5.0, // Warning!
        unit: 'units',
        dailyConsumptionRate: 0.05,
        reorderThreshold: 8.0,
        lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
        storageLocation: 'Water Treatment Pod',
      ),

      // Himadri Inventory
      InventoryItem(
        id: 'inv_hmd_kerosene',
        stationId: 'himadri',
        name: 'Arctic Aviation Kerosene & Stove Fuel',
        category: 'fuel',
        currentQuantity: 620.0,
        unit: 'liters',
        dailyConsumptionRate:
            18.0, // 34.4 days -> resupply in 45 days -> Watney ALERT
        reorderThreshold: 300.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 8)),
        storageLocation: 'Outer Shed Drum Bay',
      ),
      InventoryItem(
        id: 'inv_hmd_medical',
        stationId: 'himadri',
        name: 'Emergency Frostbite & Altitude Care Packs',
        category: 'medical',
        currentQuantity: 12.0,
        unit: 'kits',
        dailyConsumptionRate: 0.08,
        reorderThreshold: 5.0,
        lastUpdated: DateTime.now().subtract(const Duration(days: 3)),
        storageLocation: 'Station Clinic',
      ),
    ]);

    // 3. Personnel Roster
    _personnel.addAll([
      // Maitri Personnel
      Personnel(
        id: 'per_mtr_01',
        stationId: 'maitri',
        name: 'Dr. Aarav Sharma',
        role: 'station-lead',
        specialization: 'Glaciology & Ice Core Paleoclimatology',
        arrivalDate: DateTime.now().subtract(const Duration(days: 210)),
        status: 'on-station',
        bloodGroup: 'O+',
        emergencyContact: '+91 98201 44512 (Spouse: Priya Sharma)',
        avatarUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        medicalCleared: true,
      ),
      Personnel(
        id: 'per_mtr_02',
        stationId: 'maitri',
        name: 'Sqn Ldr Rajesh Varma',
        role: 'logistics',
        specialization: 'Aviation Logistics & Supply Operations',
        arrivalDate: DateTime.now().subtract(const Duration(days: 120)),
        status: 'on-station',
        bloodGroup: 'B+',
        emergencyContact: '+91 94471 22890',
        avatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
        medicalCleared: true,
      ),
      Personnel(
        id: 'per_mtr_03',
        stationId: 'maitri',
        name: 'Dr. Meera Nambiar',
        role: 'medical',
        specialization: 'Polar Emergency Medicine & Trauma',
        arrivalDate: DateTime.now().subtract(const Duration(days: 180)),
        status: 'on-station',
        bloodGroup: 'AB+',
        emergencyContact: '+91 98450 11234',
        avatarUrl:
            'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=200&q=80',
        medicalCleared: true,
      ),
      Personnel(
        id: 'per_mtr_04',
        stationId: 'maitri',
        name: 'Eng. Tenzing Norbu',
        role: 'crew',
        specialization: 'Cryogenic Power & HVAC Systems',
        arrivalDate: DateTime.now().subtract(const Duration(days: 210)),
        status: 'on-station',
        bloodGroup: 'A+',
        emergencyContact: '+91 98110 33455',
        avatarUrl:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
        medicalCleared: true,
      ),

      // Bharati Personnel
      Personnel(
        id: 'per_bhr_01',
        stationId: 'bharati',
        name: 'Dr. Sunita Deshmukh',
        role: 'station-lead',
        specialization: 'Atmospheric Physics & Ionosphere Radar',
        arrivalDate: DateTime.now().subtract(const Duration(days: 140)),
        status: 'on-station',
        bloodGroup: 'O-',
        emergencyContact: '+91 98230 77890',
        avatarUrl:
            'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=200&q=80',
        medicalCleared: true,
      ),
      Personnel(
        id: 'per_bhr_02',
        stationId: 'bharati',
        name: 'Vikramjit Singh',
        role: 'crew',
        specialization: 'Satellite Communications & Radome Tech',
        arrivalDate: DateTime.now().subtract(const Duration(days: 90)),
        status: 'on-station',
        bloodGroup: 'B+',
        emergencyContact: '+91 98150 66543',
        avatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=200&q=80',
        medicalCleared: true,
      ),

      // Himadri Personnel
      Personnel(
        id: 'per_hmd_01',
        stationId: 'himadri',
        name: 'Dr. Alok Sengupta',
        role: 'researcher',
        specialization: 'Arctic Marine Biology & Plankton Studies',
        arrivalDate: DateTime.now().subtract(const Duration(days: 40)),
        status: 'on-station',
        bloodGroup: 'A-',
        emergencyContact: '+91 98300 44321',
        avatarUrl:
            'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=200&q=80',
        medicalCleared: true,
      ),
    ]);

    // 4. Resupply Cycles & Cargo
    final cycleMaitri = ResupplyCycle(
      id: 'cycle_44_isea',
      stationId: 'maitri',
      vesselName: 'MV Vasiliy Golovnin (Chartered Icebreaker)',
      expeditionCode: '44-ISEA Antarctic Voyage',
      departureDate: DateTime.now().add(const Duration(days: 45)),
      scheduledDate: DateTime.now().add(const Duration(days: 114)),
      status: 'planned',
      departurePort: 'Cape Town Port, South Africa',
      cargoItems: [
        const CargoItem(
          id: 'cargo_01',
          cycleId: 'cycle_44_isea',
          itemName: 'Special Polar Diesel (50,000L Bulk)',
          category: 'fuel',
          quantity: 50000,
          unit: 'liters',
          weightKg: 42500,
          status: 'packed',
          recipientSection: 'Energy Command',
        ),
        const CargoItem(
          id: 'cargo_02',
          cycleId: 'cycle_44_isea',
          itemName: 'Wintering Rations & Fresh Provisions',
          category: 'food',
          quantity: 120,
          unit: 'crates',
          weightKg: 3600,
          status: 'packed',
          recipientSection: 'Kitchen & Commissary',
        ),
        const CargoItem(
          id: 'cargo_03',
          cycleId: 'cycle_44_isea',
          itemName: 'Replacement Oxygen Manifold & Cylinders',
          category: 'medical',
          quantity: 30,
          unit: 'cylinders',
          weightKg: 1800,
          status: 'shipped',
          recipientSection: 'Medical Center',
        ),
        const CargoItem(
          id: 'cargo_04',
          cycleId: 'cycle_44_isea',
          itemName: 'Piston Assemblies for Generator #1',
          category: 'spare-parts',
          quantity: 4,
          unit: 'assemblies',
          weightKg: 450,
          status: 'pending',
          recipientSection: 'Mechanical Workshop',
        ),
      ],
    );

    final cycleBharati = ResupplyCycle(
      id: 'cycle_44_bhr',
      stationId: 'bharati',
      vesselName: 'MV Vasiliy Golovnin',
      expeditionCode: '44-ISEA Leg 2',
      departureDate: DateTime.now().add(const Duration(days: 20)),
      scheduledDate: DateTime.now().add(const Duration(days: 82)),
      status: 'in-transit',
      departurePort: 'Mormugao Port (Goa) via Cape Town',
      cargoItems: [
        const CargoItem(
          id: 'cargo_bhr_01',
          cycleId: 'cycle_44_bhr',
          itemName: 'Scientific Laser Spectrometer Kit',
          category: 'equipment',
          quantity: 2,
          unit: 'crates',
          weightKg: 320,
          status: 'shipped',
          recipientSection: 'Atmospheric Lab',
        ),
        const CargoItem(
          id: 'cargo_bhr_02',
          cycleId: 'cycle_44_bhr',
          itemName: 'Desalination Membrane Replacements',
          category: 'spare-parts',
          quantity: 20,
          unit: 'cartridges',
          weightKg: 140,
          status: 'packed',
          recipientSection: 'Water Treatment',
        ),
      ],
    );

    _resupplyCycles.addAll([cycleMaitri, cycleBharati]);

    // 5. Initial Manual Alerts
    _alerts.addAll([
      AlertItem(
        id: 'alert_manual_01',
        stationId: 'himadri',
        type: 'communication-loss',
        severity: 'warning',
        message:
            'SAT-LINK uplink degradation in Ny-Ålesund sector due to severe geomagnetic ionospheric disturbance.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
      ),
      AlertItem(
        id: 'alert_manual_02',
        stationId: 'maitri',
        type: 'low-stock',
        severity: 'warning',
        message:
            'Medical Oxygen cylinder inventory at 8 units (Threshold: 12 units).',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        itemId: 'inv_mtr_oxygen',
      ),
    ]);

    // 6. Messages
    _messages.addAll([
      CommsMessage(
        id: 'msg_01',
        senderId: 'dr_aarav',
        senderName: 'Dr. Aarav Sharma (Lead)',
        senderStation: 'Maitri Station',
        recipientId: 'hq_admin',
        recipientName: 'NCPOR Goa Operations Center',
        content:
            'Ice core drilling at Site Bravo completed down to 180m. Samples secured in cryogenic vault. Generator #2 fuel burn increased by 6% due to blizzard thermal loads.',
        priority: 'urgent',
        sentAt: DateTime.now().subtract(const Duration(minutes: 25)),
        read: false,
      ),
      CommsMessage(
        id: 'msg_02',
        senderId: 'hq_admin',
        senderName: 'NCPOR Goa Mission Control',
        senderStation: 'Mainland HQ',
        recipientId: 'dr_aarav',
        recipientName: 'Dr. Aarav Sharma',
        content:
            'MV Vasiliy Golovnin loading manifest approved. Priority oxygen manifolds and Cummins injectors packed in forward cargo container C-1.',
        priority: 'routine',
        sentAt: DateTime.now().subtract(const Duration(hours: 4)),
        read: true,
      ),
      CommsMessage(
        id: 'msg_03',
        senderId: 'staff_bhr_01',
        senderName: 'Dr. Sunita Deshmukh',
        senderStation: 'Bharati Station',
        recipientId: 'staff_mtr_01',
        recipientName: 'Maitri Station Ops',
        content:
            'Maitri, we have surplus freeze-dried rations (Pack B) if you need any. Our resupply came with extra crates. Can arrange transfer via next inter-station logistics run.',
        priority: 'routine',
        sentAt: DateTime.now().subtract(const Duration(hours: 7)),
        read: false,
        stationId: 'bharati',
      ),
      CommsMessage(
        id: 'msg_04',
        senderId: 'staff_mtr_01',
        senderName: 'Dr. Aarav Sharma',
        senderStation: 'Maitri Station',
        recipientId: 'staff_hmd_01',
        recipientName: 'Himadri Station Ops',
        content:
            'Himadri, how is the VSAT signal holding up? We saw the geomagnetic alert. Let us know if you need backup comms relay through our ground terminal.',
        priority: 'routine',
        sentAt: DateTime.now().subtract(const Duration(hours: 3)),
        read: false,
        stationId: 'maitri',
      ),
    ]);

    // 7. Call Bookings
    _callBookings.addAll([
      CallBooking(
        id: 'call_01',
        stationId: 'maitri',
        personId: 'per_mtr_01',
        personName: 'Dr. Aarav Sharma',
        familyContactName: 'Priya Sharma (Spouse)',
        scheduledSlot: DateTime.now().add(const Duration(days: 1, hours: 3)),
        durationMinutes: 20,
        status: 'booked',
        channelType: 'low-res-video',
      ),
      CallBooking(
        id: 'call_02',
        stationId: 'bharati',
        personId: 'per_bhr_01',
        personName: 'Dr. Sunita Deshmukh',
        familyContactName: 'Rohan Deshmukh (Son)',
        scheduledSlot: DateTime.now().add(const Duration(hours: 6)),
        durationMinutes: 15,
        status: 'booked',
        channelType: 'satellite-voice',
      ),
      CallBooking(
        id: 'call_03',
        stationId: 'maitri',
        personId: 'per_mtr_04',
        personName: 'Eng. Tenzing Norbu',
        familyContactName: 'Sonam Norbu (Father)',
        scheduledSlot: DateTime.now().subtract(
          const Duration(days: 1, hours: 2),
        ),
        durationMinutes: 15,
        status: 'completed',
        channelType: 'satellite-voice',
      ),
    ]);

    // 8. Family invites (demo: call_01 reachable via code MTR-2026)
    _familyInvites.addAll([
      FamilyInvite(
        id: 'fam_demo_01',
        inviteCode: 'MTR-2026',
        bookingId: 'call_01',
        stationId: 'maitri',
        personId: 'per_mtr_01',
        personName: 'Dr. Aarav Sharma',
        familyContactName: 'Priya Sharma (Spouse)',
        createdByUserId: 'hq_admin_01',
        createdByName: 'Cmdr. Nitin Verma',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
    final demoBookingIdx = _callBookings.indexWhere((b) => b.id == 'call_01');
    if (demoBookingIdx != -1) {
      _callBookings[demoBookingIdx] = _callBookings[demoBookingIdx].copyWith(
        inviteCode: 'MTR-2026',
      );
    }

    // 9. Cross-Station Resource Requests (seed data)
    _resourceRequests.addAll([
      ResourceRequest(
        id: 'rr_01',
        fromStationId: 'bharati',
        fromStationName: 'Bharati Station',
        toStationId: 'maitri',
        toStationName: 'Maitri Station',
        requestedItem: 'Medical Oxygen Cylinders',
        requestedQuantity: 4,
        unit: 'cylinders',
        urgency: 'urgent',
        status: 'pending',
        requestedByUserId: 'staff_bhr_01',
        requestedByName: 'Dr. Sunita Deshmukh',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      ResourceRequest(
        id: 'rr_02',
        fromStationId: 'himadri',
        fromStationName: 'Himadri Arctic Station',
        toStationId: 'bharati',
        toStationName: 'Bharati Station',
        requestedItem: 'Cummins Diesel Injector Nozzles',
        requestedQuantity: 2,
        unit: 'units',
        urgency: 'routine',
        status: 'approved',
        requestedByUserId: 'staff_hmd_01',
        requestedByName: 'Dr. Alok Sengupta',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        responseNotes:
            'Approved. Will dispatch on next inter-station logistics run.',
        respondedByName: 'Dr. Sunita Deshmukh',
        respondedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ResourceRequest(
        id: 'rr_03',
        fromStationId: 'maitri',
        fromStationName: 'Maitri Station',
        toStationId: 'himadri',
        toStationName: 'Himadri Arctic Station',
        requestedItem: 'VSAT Backup Antenna Module',
        requestedQuantity: 1,
        unit: 'units',
        urgency: 'emergency',
        status: 'pending',
        requestedByUserId: 'staff_mtr_01',
        requestedByName: 'Dr. Aarav Sharma',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ]);
  }
}
