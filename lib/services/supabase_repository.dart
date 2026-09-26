import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/station.dart';
import '../models/inventory_item.dart';
import '../models/personnel.dart';
import '../models/resupply_cycle.dart';
import '../models/cargo_item.dart';
import '../models/alert_item.dart';
import '../models/comms_message.dart';
import '../models/call_booking.dart';
import '../models/resource_request.dart';
import '../models/inventory_audit_log.dart';
import '../models/family_invite.dart';
import 'supabase_service.dart';

/// Supabase persistence for AROHA. All methods are best-effort:
/// they silently no-op when the backend is unreachable so the app
/// stays offline-first with its in-memory store as source of truth.
///
/// Row mappers translate snake_case columns to the camelCase keys the
/// model `fromMap` factories expect (nulls flow through to defaults).
class SupabaseRepository {
  SupabaseClient? get _client => SupabaseService.clientOrNull;
  bool get isAvailable => _client != null;

  // ---------- Stations ----------

  Future<List<Station>> fetchStations() async {
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('stations').select();
    return [for (final r in (rows as List)) stationFromRow(r)];
  }

  Future<void> upsertStations(List<Station> stations) async {
    final client = _client;
    if (client == null || stations.isEmpty) return;
    await client.from('stations').upsert([
      for (final s in stations) stationToRow(s),
    ]);
  }

  // ---------- Inventory ----------

  Future<List<InventoryItem>> fetchInventory() async {
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('inventory_items').select();
    return [for (final r in (rows as List)) inventoryFromRow(r)];
  }

  Future<void> upsertInventoryItem(InventoryItem item) async {
    await _upsert('inventory_items', inventoryToRow(item));
  }

  Future<void> upsertInventoryItems(List<InventoryItem> items) async {
    await _upsertMany('inventory_items', [
      for (final i in items) inventoryToRow(i),
    ]);
  }

  Future<void> deleteInventoryItem(String id) async {
    await _delete('inventory_items', id);
  }

  // ---------- Personnel ----------

  Future<List<Personnel>> fetchPersonnel() async {
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('personnel').select();
    return [for (final r in (rows as List)) personnelFromRow(r)];
  }

  Future<void> upsertPerson(Personnel person) async {
    await _upsert('personnel', personnelToRow(person));
  }

  Future<void> upsertPersonnel(List<Personnel> roster) async {
    await _upsertMany('personnel', [for (final p in roster) personnelToRow(p)]);
  }

  Future<void> deletePerson(String id) async {
    await _delete('personnel', id);
  }

  // ---------- Resupply + cargo ----------

  Future<List<ResupplyCycle>> fetchCycles() async {
    final client = _client;
    if (client == null) return [];
    final cycleRows = await client.from('resupply_cycles').select();
    final cargoRows = await client.from('cargo_items').select();
    final cargoByCycle = <String, List<CargoItem>>{};
    for (final r in (cargoRows as List)) {
      final item = cargoFromRow(r);
      cargoByCycle.putIfAbsent(item.cycleId, () => []).add(item);
    }
    return [
      for (final r in (cycleRows as List))
        cycleFromRow(r, cargoByCycle[r['id']] ?? const []),
    ];
  }

  Future<void> upsertCycles(List<ResupplyCycle> cycles) async {
    final client = _client;
    if (client == null || cycles.isEmpty) return;
    await client.from('resupply_cycles').upsert([
      for (final c in cycles) cycleToRow(c),
    ]);
    final cargo = [for (final c in cycles) ...c.cargoItems];
    if (cargo.isNotEmpty) {
      await client.from('cargo_items').upsert([
        for (final item in cargo) cargoToRow(item),
      ]);
    }
  }

  Future<void> upsertCargoItem(CargoItem item) async {
    await _upsert('cargo_items', cargoToRow(item));
  }

  // ---------- Alerts (manual only — watney_* are derived) ----------

  Future<List<AlertItem>> fetchManualAlerts() async {
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('alerts').select();
    return [
      for (final r in (rows as List))
        if (!(r['id'] as String).startsWith('watney_')) alertFromRow(r),
    ];
  }

  Future<void> upsertAlert(AlertItem alert) async {
    if (alert.id.startsWith('watney_')) return;
    await _upsert('alerts', alertToRow(alert));
  }

  Future<void> upsertManualAlerts(List<AlertItem> alerts) async {
    final manual = [
      for (final a in alerts)
        if (!a.id.startsWith('watney_')) alertToRow(a),
    ];
    await _upsertMany('alerts', manual);
  }

  // ---------- Messages ----------

  Future<List<CommsMessage>> fetchMessages() async {
    final client = _client;
    if (client == null) return [];
    final rows = await client
        .from('comms_messages')
        .select()
        .order('sent_at', ascending: false);
    return [for (final r in (rows as List)) messageFromRow(r)];
  }

  Future<void> upsertMessage(CommsMessage message) async {
    await _upsert('comms_messages', messageToRow(message));
  }

  Future<void> upsertMessages(List<CommsMessage> messages) async {
    await _upsertMany('comms_messages', [
      for (final m in messages) messageToRow(m),
    ]);
  }

  // ---------- Call bookings ----------

  Future<List<CallBooking>> fetchBookings() async {
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('call_bookings').select();
    return [for (final r in (rows as List)) bookingFromRow(r)];
  }

  Future<void> upsertBooking(CallBooking booking) async {
    await _upsert('call_bookings', bookingToRow(booking));
  }

  Future<void> upsertBookings(List<CallBooking> bookings) async {
    await _upsertMany('call_bookings', [
      for (final b in bookings) bookingToRow(b),
    ]);
  }

  // ---------- Resource requests ----------

  Future<List<ResourceRequest>> fetchResourceRequests() async {
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('resource_requests').select();
    return [for (final r in (rows as List)) requestFromRow(r)];
  }

  Future<void> upsertResourceRequest(ResourceRequest request) async {
    final map = request.toFirestore()
      ..['id'] = request.id
      ..['createdAt'] = request.createdAt.toIso8601String()
      ..['respondedAt'] = request.respondedAt?.toIso8601String();
    await _upsert('resource_requests', _snakeMap(map));
  }

  Future<void> upsertResourceRequests(List<ResourceRequest> requests) async {
    final client = _client;
    if (client == null || requests.isEmpty) return;
    for (final r in requests) {
      await upsertResourceRequest(r);
    }
  }

  // ---------- Family invites ----------

  Future<List<FamilyInvite>> fetchInvites() async {
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('family_invites').select();
    return [for (final r in (rows as List)) inviteFromRow(r)];
  }

  Future<void> upsertInvite(FamilyInvite invite) async {
    await _upsert('family_invites', inviteToRow(invite));
  }

  Future<void> upsertInvites(List<FamilyInvite> invites) async {
    await _upsertMany('family_invites', [
      for (final i in invites) inviteToRow(i),
    ]);
  }

  // ---------- Audit logs ----------

  Future<List<InventoryAuditLog>> fetchAuditLogs() async {
    final client = _client;
    if (client == null) return [];
    final rows = await client
        .from('inventory_audit_logs')
        .select()
        .order('timestamp', ascending: false)
        .limit(200);
    return [for (final r in (rows as List)) auditFromRow(r)];
  }

  Future<void> insertAuditLog(InventoryAuditLog log) async {
    final client = _client;
    if (client == null) return;
    await client.from('inventory_audit_logs').insert(auditToRow(log));
  }

  // ---------- Realtime ----------

  /// Live updates for ops-critical tables. The callback receives the
  /// table name; callers re-pull and merge. Never throws.
  void subscribeToRemote(void Function(String table) onEvent) {
    try {
      final client = _client;
      if (client == null) return;
      client
          .channel('aroha_ops')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'alerts',
            callback: (_) => onEvent('alerts'),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'comms_messages',
            callback: (_) => onEvent('comms_messages'),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'resource_requests',
            callback: (_) => onEvent('resource_requests'),
          )
          .subscribe();
    } catch (_) {}
  }

  // ---------- Helpers (all guarded) ----------

  Future<void> _upsert(String table, Map<String, dynamic> row) async {
    try {
      final client = _client;
      if (client == null) return;
      await client.from(table).upsert(row);
    } catch (_) {}
  }

  Future<void> _upsertMany(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final client = _client;
      if (client == null || rows.isEmpty) return;
      await client.from(table).upsert(rows);
    } catch (_) {}
  }

  Future<void> _delete(String table, String id) async {
    try {
      final client = _client;
      if (client == null) return;
      await client.from(table).delete().eq('id', id);
    } catch (_) {}
  }
}

// ---------- Row mappers (pure, unit-tested) ----------

Map<String, dynamic> _snakeMap(Map<String, dynamic> camel) {
  final out = <String, dynamic>{};
  for (final e in camel.entries) {
    final snake = e.key.replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
    out[snake] = e.value;
  }
  return out;
}

Station stationFromRow(Map<String, dynamic> r) =>
    Station.fromMap(r['id'] as String, {
      'name': r['name'],
      'code': r['code'],
      'location': r['location'],
      'coordinates': r['coordinates'],
      'status': r['status'],
      'lastContact': r['last_contact'],
      'powerLevel': r['power_level'],
      'temperature': r['temperature'],
      'windSpeed': r['wind_speed'],
      'satLinkSignal': r['sat_link_signal'],
      'sectorLiveCamUrl': r['sector_live_cam_url'],
      'activePersonnelCount': r['active_personnel_count'],
      'nextResupplyDate': r['next_resupply_date'],
    });

Map<String, dynamic> stationToRow(Station s) => {
  'id': s.id,
  ..._snakeMap(s.toFirestore()),
};

InventoryItem inventoryFromRow(Map<String, dynamic> r) =>
    InventoryItem.fromMap(r['id'] as String, {
      'stationId': r['station_id'],
      'name': r['name'],
      'category': r['category'],
      'currentQuantity': r['current_quantity'],
      'unit': r['unit'],
      'dailyConsumptionRate': r['daily_consumption_rate'],
      'reorderThreshold': r['reorder_threshold'],
      'lastUpdated': r['last_updated'],
      'storageLocation': r['storage_location'],
      'notes': r['notes'],
    });

Map<String, dynamic> inventoryToRow(InventoryItem i) => {
  'id': i.id,
  ..._snakeMap(i.toFirestore()),
};

Personnel personnelFromRow(Map<String, dynamic> r) =>
    Personnel.fromMap(r['id'] as String, {
      'stationId': r['station_id'],
      'name': r['name'],
      'role': r['role'],
      'specialization': r['specialization'],
      'arrivalDate': r['arrival_date'],
      'departureDate': r['departure_date'],
      'status': r['status'],
      'bloodGroup': r['blood_group'],
      'emergencyContact': r['emergency_contact'],
      'avatarUrl': r['avatar_url'],
      'medicalCleared': r['medical_cleared'],
    });

Map<String, dynamic> personnelToRow(Personnel p) => {
  'id': p.id,
  ..._snakeMap(p.toFirestore()),
};

ResupplyCycle cycleFromRow(Map<String, dynamic> r, List<CargoItem> cargo) =>
    ResupplyCycle.fromMap(r['id'] as String, {
      'stationId': r['station_id'],
      'vesselName': r['vessel_name'],
      'expeditionCode': r['expedition_code'],
      'departureDate': r['departure_date'],
      'scheduledDate': r['scheduled_date'],
      'status': r['status'],
      'departurePort': r['departure_port'],
    }, cargo);

Map<String, dynamic> cycleToRow(ResupplyCycle c) => {
  'id': c.id,
  ..._snakeMap(c.toFirestore()),
};

CargoItem cargoFromRow(Map<String, dynamic> r) =>
    CargoItem.fromMap(r['id'] as String, {
      'cycleId': r['cycle_id'],
      'itemName': r['item_name'],
      'category': r['category'],
      'quantity': r['quantity'],
      'unit': r['unit'],
      'weightKg': r['weight_kg'],
      'status': r['status'],
      'recipientSection': r['recipient_section'],
    });

Map<String, dynamic> cargoToRow(CargoItem c) => {
  'id': c.id,
  ..._snakeMap(c.toFirestore()),
};

AlertItem alertFromRow(Map<String, dynamic> r) =>
    AlertItem.fromMap(r['id'] as String, {
      'stationId': r['station_id'],
      'type': r['type'],
      'severity': r['severity'],
      'message': r['message'],
      'createdAt': r['created_at'],
      'resolved': r['resolved'],
      'itemId': r['item_id'],
    });

Map<String, dynamic> alertToRow(AlertItem a) => {
  'id': a.id,
  ..._snakeMap(a.toFirestore()),
};

CommsMessage messageFromRow(Map<String, dynamic> r) =>
    CommsMessage.fromMap(r['id'] as String, {
      'senderId': r['sender_id'],
      'senderName': r['sender_name'],
      'senderStation': r['sender_station'],
      'recipientId': r['recipient_id'],
      'recipientName': r['recipient_name'],
      'content': r['content'],
      'priority': r['priority'],
      'sentAt': r['sent_at'],
      'read': r['read'],
      'isEncrypted': r['is_encrypted'],
      'stationId': r['station_id'],
      'recipientStationId': r['recipient_station_id'],
    });

Map<String, dynamic> messageToRow(CommsMessage m) => {
  'id': m.id,
  ..._snakeMap(m.toFirestore()),
};

CallBooking bookingFromRow(Map<String, dynamic> r) =>
    CallBooking.fromMap(r['id'] as String, {
      'stationId': r['station_id'],
      'personId': r['person_id'],
      'personName': r['person_name'],
      'familyContactName': r['family_contact_name'],
      'scheduledSlot': r['scheduled_slot'],
      'durationMinutes': r['duration_minutes'],
      'status': r['status'],
      'channelType': r['channel_type'],
      'familyConsentGiven': r['family_consent_given'],
      'briefingAcked': r['briefing_acked'],
      'recordingRef': r['recording_ref'],
      'inviteCode': r['invite_code'],
      'crewDisclaimerSigned': r['crew_disclaimer_signed'],
      'crewDisclaimerBy': r['crew_disclaimer_by'],
      'crewDisclaimerAt': r['crew_disclaimer_at'],
    });

Map<String, dynamic> bookingToRow(CallBooking b) => {
  'id': b.id,
  ..._snakeMap(b.toFirestore()),
};

ResourceRequest requestFromRow(Map<String, dynamic> r) =>
    ResourceRequest.fromMap(r['id'] as String, {
      'fromStationId': r['from_station_id'],
      'fromStationName': r['from_station_name'],
      'toStationId': r['to_station_id'],
      'toStationName': r['to_station_name'],
      'requestedItem': r['requested_item'],
      'requestedQuantity': r['requested_quantity'],
      'unit': r['unit'],
      'urgency': r['urgency'],
      'status': r['status'],
      'requestedByUserId': r['requested_by_user_id'],
      'requestedByName': r['requested_by_name'],
      'createdAt': r['created_at'],
      'responseNotes': r['response_notes'],
      'respondedByName': r['responded_by_name'],
      'respondedAt': r['responded_at'],
    });

FamilyInvite inviteFromRow(Map<String, dynamic> r) => FamilyInvite(
  id: r['id'] as String,
  inviteCode: r['invite_code'] ?? '',
  bookingId: r['booking_id'] ?? '',
  stationId: r['station_id'] ?? '',
  personId: r['person_id'] ?? '',
  personName: r['person_name'] ?? '',
  familyContactName: r['family_contact_name'] ?? '',
  createdByUserId: r['created_by_user_id'] ?? '',
  createdByName: r['created_by_name'] ?? '',
  createdAt: r['created_at'] != null
      ? DateTime.parse(r['created_at'] as String)
      : DateTime.now(),
  consentGiven: r['consent_given'] ?? false,
  consentAt: r['consent_at'] != null
      ? DateTime.tryParse(r['consent_at'] as String)
      : null,
  briefingAcked: r['briefing_acked'] ?? false,
  disclaimerAccepted: r['disclaimer_accepted'] ?? false,
  disclaimerSignedName: r['disclaimer_signed_name'],
  disclaimerSignedAt: r['disclaimer_signed_at'] != null
      ? DateTime.tryParse(r['disclaimer_signed_at'] as String)
      : null,
  disclaimerVersion: r['disclaimer_version'] ?? 'v1',
);

Map<String, dynamic> inviteToRow(FamilyInvite i) => {
  'id': i.id,
  'invite_code': i.inviteCode,
  'booking_id': i.bookingId,
  'station_id': i.stationId,
  'person_id': i.personId,
  'person_name': i.personName,
  'family_contact_name': i.familyContactName,
  'created_by_user_id': i.createdByUserId,
  'created_by_name': i.createdByName,
  'created_at': i.createdAt.toIso8601String(),
  'consent_given': i.consentGiven,
  'consent_at': i.consentAt?.toIso8601String(),
  'briefing_acked': i.briefingAcked,
  'disclaimer_accepted': i.disclaimerAccepted,
  'disclaimer_signed_name': i.disclaimerSignedName,
  'disclaimer_signed_at': i.disclaimerSignedAt?.toIso8601String(),
  'disclaimer_version': i.disclaimerVersion,
};

InventoryAuditLog auditFromRow(Map<String, dynamic> r) =>
    InventoryAuditLog.fromMap({
      'id': r['id'],
      'itemId': r['item_id'],
      'itemName': r['item_name'],
      'stationId': r['station_id'],
      'action': r['action'],
      'previousQuantity': r['previous_quantity'],
      'newQuantity': r['new_quantity'],
      'performedByUserId': r['performed_by_user_id'],
      'performedByUserName': r['performed_by_user_name'],
      'timestamp': r['timestamp'],
      'notes': r['notes'],
    });

Map<String, dynamic> auditToRow(InventoryAuditLog l) => {
  'id': l.id,
  ..._snakeMap(l.toMap()..remove('id')),
};
