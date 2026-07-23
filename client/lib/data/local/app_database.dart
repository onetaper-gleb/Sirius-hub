import 'dart:convert';
import 'package:drift/drift.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Teacher {
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? fio;

  Teacher({this.firstName, this.lastName, this.middleName, this.fio});

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    middleName: json['middle_name'] as String?,
    fio: json['fio'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'middle_name': middleName,
    'fio': fio,
  };
}

class TeacherListConverter extends TypeConverter<List<Teacher>, String> {
  const TeacherListConverter();

  @override
  List<Teacher> fromSql(String fromDb) {
    final List<dynamic> decoded = json.decode(fromDb);
    return decoded.map((e) => Teacher.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  String toSql(List<Teacher> value) {
    final List<Map<String, dynamic>> encoded = value.map((e) => e.toJson()).toList();
    return json.encode(encoded);
  }
}

@DataClassName('ScheduleDbEntity')
class ScheduleEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get date => text()();
  TextColumn get dayWeek => text()();

  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  IntColumn get numberPair => integer()();
  TextColumn get discipline => text()();

  TextColumn get groupType => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get classroom => text().nullable()();
  TextColumn get comment => text().nullable()();
  TextColumn get place => text().nullable()();
  TextColumn get urlOnline => text().nullable()();

  TextColumn get groupName => text()();
  TextColumn get code => text().nullable()();
  TextColumn get color => text().nullable()();

  TextColumn get teachers => text().map(const TeacherListConverter())();
}
@DriftDatabase(tables: [ScheduleEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> clearGroupSchedule(String groupName) {
    return (delete(scheduleEvents)..where((tbl) => tbl.groupName.equals(groupName))).go();
  }

  Future<List<ScheduleDbEntity>> getCachedSchedule(String groupName) {
    return (select(scheduleEvents)..where((tbl) => tbl.groupName.equals(groupName))).get();
  }

  Future<void> insertSchedule(List<ScheduleEventsCompanion> events) async {
    await batch((batch) {
      batch.insertAll(scheduleEvents, events);
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'schedule_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
