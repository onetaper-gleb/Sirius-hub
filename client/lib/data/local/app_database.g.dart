// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ScheduleEventsTable extends ScheduleEvents
    with TableInfo<$ScheduleEventsTable, ScheduleDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayWeekMeta = const VerificationMeta(
    'dayWeek',
  );
  @override
  late final GeneratedColumn<String> dayWeek = GeneratedColumn<String>(
    'day_week',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberPairMeta = const VerificationMeta(
    'numberPair',
  );
  @override
  late final GeneratedColumn<int> numberPair = GeneratedColumn<int>(
    'number_pair',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _disciplineMeta = const VerificationMeta(
    'discipline',
  );
  @override
  late final GeneratedColumn<String> discipline = GeneratedColumn<String>(
    'discipline',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupTypeMeta = const VerificationMeta(
    'groupType',
  );
  @override
  late final GeneratedColumn<String> groupType = GeneratedColumn<String>(
    'group_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _classroomMeta = const VerificationMeta(
    'classroom',
  );
  @override
  late final GeneratedColumn<String> classroom = GeneratedColumn<String>(
    'classroom',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlOnlineMeta = const VerificationMeta(
    'urlOnline',
  );
  @override
  late final GeneratedColumn<String> urlOnline = GeneratedColumn<String>(
    'url_online',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<Teacher>, String> teachers =
      GeneratedColumn<String>(
        'teachers',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<Teacher>>($ScheduleEventsTable.$converterteachers);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    dayWeek,
    startTime,
    endTime,
    numberPair,
    discipline,
    groupType,
    address,
    classroom,
    comment,
    place,
    urlOnline,
    groupName,
    code,
    color,
    teachers,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleDbEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('day_week')) {
      context.handle(
        _dayWeekMeta,
        dayWeek.isAcceptableOrUnknown(data['day_week']!, _dayWeekMeta),
      );
    } else if (isInserting) {
      context.missing(_dayWeekMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('number_pair')) {
      context.handle(
        _numberPairMeta,
        numberPair.isAcceptableOrUnknown(data['number_pair']!, _numberPairMeta),
      );
    } else if (isInserting) {
      context.missing(_numberPairMeta);
    }
    if (data.containsKey('discipline')) {
      context.handle(
        _disciplineMeta,
        discipline.isAcceptableOrUnknown(data['discipline']!, _disciplineMeta),
      );
    } else if (isInserting) {
      context.missing(_disciplineMeta);
    }
    if (data.containsKey('group_type')) {
      context.handle(
        _groupTypeMeta,
        groupType.isAcceptableOrUnknown(data['group_type']!, _groupTypeMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('classroom')) {
      context.handle(
        _classroomMeta,
        classroom.isAcceptableOrUnknown(data['classroom']!, _classroomMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    }
    if (data.containsKey('url_online')) {
      context.handle(
        _urlOnlineMeta,
        urlOnline.isAcceptableOrUnknown(data['url_online']!, _urlOnlineMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleDbEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleDbEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      dayWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_week'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time'],
      )!,
      numberPair: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number_pair'],
      )!,
      discipline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discipline'],
      )!,
      groupType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_type'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      classroom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}classroom'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      ),
      urlOnline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_online'],
      ),
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      teachers: $ScheduleEventsTable.$converterteachers.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}teachers'],
        )!,
      ),
    );
  }

  @override
  $ScheduleEventsTable createAlias(String alias) {
    return $ScheduleEventsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<Teacher>, String> $converterteachers =
      const TeacherListConverter();
}

class ScheduleDbEntity extends DataClass
    implements Insertable<ScheduleDbEntity> {
  final int id;
  final String date;
  final String dayWeek;
  final String startTime;
  final String endTime;
  final int numberPair;
  final String discipline;
  final String? groupType;
  final String? address;
  final String? classroom;
  final String? comment;
  final String? place;
  final String? urlOnline;
  final String groupName;
  final String? code;
  final String? color;
  final List<Teacher> teachers;
  const ScheduleDbEntity({
    required this.id,
    required this.date,
    required this.dayWeek,
    required this.startTime,
    required this.endTime,
    required this.numberPair,
    required this.discipline,
    this.groupType,
    this.address,
    this.classroom,
    this.comment,
    this.place,
    this.urlOnline,
    required this.groupName,
    this.code,
    this.color,
    required this.teachers,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    map['day_week'] = Variable<String>(dayWeek);
    map['start_time'] = Variable<String>(startTime);
    map['end_time'] = Variable<String>(endTime);
    map['number_pair'] = Variable<int>(numberPair);
    map['discipline'] = Variable<String>(discipline);
    if (!nullToAbsent || groupType != null) {
      map['group_type'] = Variable<String>(groupType);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || classroom != null) {
      map['classroom'] = Variable<String>(classroom);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    if (!nullToAbsent || place != null) {
      map['place'] = Variable<String>(place);
    }
    if (!nullToAbsent || urlOnline != null) {
      map['url_online'] = Variable<String>(urlOnline);
    }
    map['group_name'] = Variable<String>(groupName);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    {
      map['teachers'] = Variable<String>(
        $ScheduleEventsTable.$converterteachers.toSql(teachers),
      );
    }
    return map;
  }

  ScheduleEventsCompanion toCompanion(bool nullToAbsent) {
    return ScheduleEventsCompanion(
      id: Value(id),
      date: Value(date),
      dayWeek: Value(dayWeek),
      startTime: Value(startTime),
      endTime: Value(endTime),
      numberPair: Value(numberPair),
      discipline: Value(discipline),
      groupType: groupType == null && nullToAbsent
          ? const Value.absent()
          : Value(groupType),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      classroom: classroom == null && nullToAbsent
          ? const Value.absent()
          : Value(classroom),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      place: place == null && nullToAbsent
          ? const Value.absent()
          : Value(place),
      urlOnline: urlOnline == null && nullToAbsent
          ? const Value.absent()
          : Value(urlOnline),
      groupName: Value(groupName),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      teachers: Value(teachers),
    );
  }

  factory ScheduleDbEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleDbEntity(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      dayWeek: serializer.fromJson<String>(json['dayWeek']),
      startTime: serializer.fromJson<String>(json['startTime']),
      endTime: serializer.fromJson<String>(json['endTime']),
      numberPair: serializer.fromJson<int>(json['numberPair']),
      discipline: serializer.fromJson<String>(json['discipline']),
      groupType: serializer.fromJson<String?>(json['groupType']),
      address: serializer.fromJson<String?>(json['address']),
      classroom: serializer.fromJson<String?>(json['classroom']),
      comment: serializer.fromJson<String?>(json['comment']),
      place: serializer.fromJson<String?>(json['place']),
      urlOnline: serializer.fromJson<String?>(json['urlOnline']),
      groupName: serializer.fromJson<String>(json['groupName']),
      code: serializer.fromJson<String?>(json['code']),
      color: serializer.fromJson<String?>(json['color']),
      teachers: serializer.fromJson<List<Teacher>>(json['teachers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'dayWeek': serializer.toJson<String>(dayWeek),
      'startTime': serializer.toJson<String>(startTime),
      'endTime': serializer.toJson<String>(endTime),
      'numberPair': serializer.toJson<int>(numberPair),
      'discipline': serializer.toJson<String>(discipline),
      'groupType': serializer.toJson<String?>(groupType),
      'address': serializer.toJson<String?>(address),
      'classroom': serializer.toJson<String?>(classroom),
      'comment': serializer.toJson<String?>(comment),
      'place': serializer.toJson<String?>(place),
      'urlOnline': serializer.toJson<String?>(urlOnline),
      'groupName': serializer.toJson<String>(groupName),
      'code': serializer.toJson<String?>(code),
      'color': serializer.toJson<String?>(color),
      'teachers': serializer.toJson<List<Teacher>>(teachers),
    };
  }

  ScheduleDbEntity copyWith({
    int? id,
    String? date,
    String? dayWeek,
    String? startTime,
    String? endTime,
    int? numberPair,
    String? discipline,
    Value<String?> groupType = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> classroom = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    Value<String?> place = const Value.absent(),
    Value<String?> urlOnline = const Value.absent(),
    String? groupName,
    Value<String?> code = const Value.absent(),
    Value<String?> color = const Value.absent(),
    List<Teacher>? teachers,
  }) => ScheduleDbEntity(
    id: id ?? this.id,
    date: date ?? this.date,
    dayWeek: dayWeek ?? this.dayWeek,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    numberPair: numberPair ?? this.numberPair,
    discipline: discipline ?? this.discipline,
    groupType: groupType.present ? groupType.value : this.groupType,
    address: address.present ? address.value : this.address,
    classroom: classroom.present ? classroom.value : this.classroom,
    comment: comment.present ? comment.value : this.comment,
    place: place.present ? place.value : this.place,
    urlOnline: urlOnline.present ? urlOnline.value : this.urlOnline,
    groupName: groupName ?? this.groupName,
    code: code.present ? code.value : this.code,
    color: color.present ? color.value : this.color,
    teachers: teachers ?? this.teachers,
  );
  ScheduleDbEntity copyWithCompanion(ScheduleEventsCompanion data) {
    return ScheduleDbEntity(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      dayWeek: data.dayWeek.present ? data.dayWeek.value : this.dayWeek,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      numberPair: data.numberPair.present
          ? data.numberPair.value
          : this.numberPair,
      discipline: data.discipline.present
          ? data.discipline.value
          : this.discipline,
      groupType: data.groupType.present ? data.groupType.value : this.groupType,
      address: data.address.present ? data.address.value : this.address,
      classroom: data.classroom.present ? data.classroom.value : this.classroom,
      comment: data.comment.present ? data.comment.value : this.comment,
      place: data.place.present ? data.place.value : this.place,
      urlOnline: data.urlOnline.present ? data.urlOnline.value : this.urlOnline,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      code: data.code.present ? data.code.value : this.code,
      color: data.color.present ? data.color.value : this.color,
      teachers: data.teachers.present ? data.teachers.value : this.teachers,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleDbEntity(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('dayWeek: $dayWeek, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('numberPair: $numberPair, ')
          ..write('discipline: $discipline, ')
          ..write('groupType: $groupType, ')
          ..write('address: $address, ')
          ..write('classroom: $classroom, ')
          ..write('comment: $comment, ')
          ..write('place: $place, ')
          ..write('urlOnline: $urlOnline, ')
          ..write('groupName: $groupName, ')
          ..write('code: $code, ')
          ..write('color: $color, ')
          ..write('teachers: $teachers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    dayWeek,
    startTime,
    endTime,
    numberPair,
    discipline,
    groupType,
    address,
    classroom,
    comment,
    place,
    urlOnline,
    groupName,
    code,
    color,
    teachers,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleDbEntity &&
          other.id == this.id &&
          other.date == this.date &&
          other.dayWeek == this.dayWeek &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.numberPair == this.numberPair &&
          other.discipline == this.discipline &&
          other.groupType == this.groupType &&
          other.address == this.address &&
          other.classroom == this.classroom &&
          other.comment == this.comment &&
          other.place == this.place &&
          other.urlOnline == this.urlOnline &&
          other.groupName == this.groupName &&
          other.code == this.code &&
          other.color == this.color &&
          other.teachers == this.teachers);
}

class ScheduleEventsCompanion extends UpdateCompanion<ScheduleDbEntity> {
  final Value<int> id;
  final Value<String> date;
  final Value<String> dayWeek;
  final Value<String> startTime;
  final Value<String> endTime;
  final Value<int> numberPair;
  final Value<String> discipline;
  final Value<String?> groupType;
  final Value<String?> address;
  final Value<String?> classroom;
  final Value<String?> comment;
  final Value<String?> place;
  final Value<String?> urlOnline;
  final Value<String> groupName;
  final Value<String?> code;
  final Value<String?> color;
  final Value<List<Teacher>> teachers;
  const ScheduleEventsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.dayWeek = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.numberPair = const Value.absent(),
    this.discipline = const Value.absent(),
    this.groupType = const Value.absent(),
    this.address = const Value.absent(),
    this.classroom = const Value.absent(),
    this.comment = const Value.absent(),
    this.place = const Value.absent(),
    this.urlOnline = const Value.absent(),
    this.groupName = const Value.absent(),
    this.code = const Value.absent(),
    this.color = const Value.absent(),
    this.teachers = const Value.absent(),
  });
  ScheduleEventsCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    required String dayWeek,
    required String startTime,
    required String endTime,
    required int numberPair,
    required String discipline,
    this.groupType = const Value.absent(),
    this.address = const Value.absent(),
    this.classroom = const Value.absent(),
    this.comment = const Value.absent(),
    this.place = const Value.absent(),
    this.urlOnline = const Value.absent(),
    required String groupName,
    this.code = const Value.absent(),
    this.color = const Value.absent(),
    required List<Teacher> teachers,
  }) : date = Value(date),
       dayWeek = Value(dayWeek),
       startTime = Value(startTime),
       endTime = Value(endTime),
       numberPair = Value(numberPair),
       discipline = Value(discipline),
       groupName = Value(groupName),
       teachers = Value(teachers);
  static Insertable<ScheduleDbEntity> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<String>? dayWeek,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<int>? numberPair,
    Expression<String>? discipline,
    Expression<String>? groupType,
    Expression<String>? address,
    Expression<String>? classroom,
    Expression<String>? comment,
    Expression<String>? place,
    Expression<String>? urlOnline,
    Expression<String>? groupName,
    Expression<String>? code,
    Expression<String>? color,
    Expression<String>? teachers,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (dayWeek != null) 'day_week': dayWeek,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (numberPair != null) 'number_pair': numberPair,
      if (discipline != null) 'discipline': discipline,
      if (groupType != null) 'group_type': groupType,
      if (address != null) 'address': address,
      if (classroom != null) 'classroom': classroom,
      if (comment != null) 'comment': comment,
      if (place != null) 'place': place,
      if (urlOnline != null) 'url_online': urlOnline,
      if (groupName != null) 'group_name': groupName,
      if (code != null) 'code': code,
      if (color != null) 'color': color,
      if (teachers != null) 'teachers': teachers,
    });
  }

  ScheduleEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<String>? dayWeek,
    Value<String>? startTime,
    Value<String>? endTime,
    Value<int>? numberPair,
    Value<String>? discipline,
    Value<String?>? groupType,
    Value<String?>? address,
    Value<String?>? classroom,
    Value<String?>? comment,
    Value<String?>? place,
    Value<String?>? urlOnline,
    Value<String>? groupName,
    Value<String?>? code,
    Value<String?>? color,
    Value<List<Teacher>>? teachers,
  }) {
    return ScheduleEventsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      dayWeek: dayWeek ?? this.dayWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      numberPair: numberPair ?? this.numberPair,
      discipline: discipline ?? this.discipline,
      groupType: groupType ?? this.groupType,
      address: address ?? this.address,
      classroom: classroom ?? this.classroom,
      comment: comment ?? this.comment,
      place: place ?? this.place,
      urlOnline: urlOnline ?? this.urlOnline,
      groupName: groupName ?? this.groupName,
      code: code ?? this.code,
      color: color ?? this.color,
      teachers: teachers ?? this.teachers,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (dayWeek.present) {
      map['day_week'] = Variable<String>(dayWeek.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (numberPair.present) {
      map['number_pair'] = Variable<int>(numberPair.value);
    }
    if (discipline.present) {
      map['discipline'] = Variable<String>(discipline.value);
    }
    if (groupType.present) {
      map['group_type'] = Variable<String>(groupType.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (classroom.present) {
      map['classroom'] = Variable<String>(classroom.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (urlOnline.present) {
      map['url_online'] = Variable<String>(urlOnline.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (teachers.present) {
      map['teachers'] = Variable<String>(
        $ScheduleEventsTable.$converterteachers.toSql(teachers.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleEventsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('dayWeek: $dayWeek, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('numberPair: $numberPair, ')
          ..write('discipline: $discipline, ')
          ..write('groupType: $groupType, ')
          ..write('address: $address, ')
          ..write('classroom: $classroom, ')
          ..write('comment: $comment, ')
          ..write('place: $place, ')
          ..write('urlOnline: $urlOnline, ')
          ..write('groupName: $groupName, ')
          ..write('code: $code, ')
          ..write('color: $color, ')
          ..write('teachers: $teachers')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScheduleEventsTable scheduleEvents = $ScheduleEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [scheduleEvents];
}

typedef $$ScheduleEventsTableCreateCompanionBuilder =
    ScheduleEventsCompanion Function({
      Value<int> id,
      required String date,
      required String dayWeek,
      required String startTime,
      required String endTime,
      required int numberPair,
      required String discipline,
      Value<String?> groupType,
      Value<String?> address,
      Value<String?> classroom,
      Value<String?> comment,
      Value<String?> place,
      Value<String?> urlOnline,
      required String groupName,
      Value<String?> code,
      Value<String?> color,
      required List<Teacher> teachers,
    });
typedef $$ScheduleEventsTableUpdateCompanionBuilder =
    ScheduleEventsCompanion Function({
      Value<int> id,
      Value<String> date,
      Value<String> dayWeek,
      Value<String> startTime,
      Value<String> endTime,
      Value<int> numberPair,
      Value<String> discipline,
      Value<String?> groupType,
      Value<String?> address,
      Value<String?> classroom,
      Value<String?> comment,
      Value<String?> place,
      Value<String?> urlOnline,
      Value<String> groupName,
      Value<String?> code,
      Value<String?> color,
      Value<List<Teacher>> teachers,
    });

class $$ScheduleEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduleEventsTable> {
  $$ScheduleEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayWeek => $composableBuilder(
    column: $table.dayWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numberPair => $composableBuilder(
    column: $table.numberPair,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get discipline => $composableBuilder(
    column: $table.discipline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupType => $composableBuilder(
    column: $table.groupType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classroom => $composableBuilder(
    column: $table.classroom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlOnline => $composableBuilder(
    column: $table.urlOnline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<Teacher>, List<Teacher>, String>
  get teachers => $composableBuilder(
    column: $table.teachers,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$ScheduleEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduleEventsTable> {
  $$ScheduleEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayWeek => $composableBuilder(
    column: $table.dayWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numberPair => $composableBuilder(
    column: $table.numberPair,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discipline => $composableBuilder(
    column: $table.discipline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupType => $composableBuilder(
    column: $table.groupType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classroom => $composableBuilder(
    column: $table.classroom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlOnline => $composableBuilder(
    column: $table.urlOnline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teachers => $composableBuilder(
    column: $table.teachers,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduleEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduleEventsTable> {
  $$ScheduleEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get dayWeek =>
      $composableBuilder(column: $table.dayWeek, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<int> get numberPair => $composableBuilder(
    column: $table.numberPair,
    builder: (column) => column,
  );

  GeneratedColumn<String> get discipline => $composableBuilder(
    column: $table.discipline,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupType =>
      $composableBuilder(column: $table.groupType, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get classroom =>
      $composableBuilder(column: $table.classroom, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumn<String> get urlOnline =>
      $composableBuilder(column: $table.urlOnline, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<Teacher>, String> get teachers =>
      $composableBuilder(column: $table.teachers, builder: (column) => column);
}

class $$ScheduleEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduleEventsTable,
          ScheduleDbEntity,
          $$ScheduleEventsTableFilterComposer,
          $$ScheduleEventsTableOrderingComposer,
          $$ScheduleEventsTableAnnotationComposer,
          $$ScheduleEventsTableCreateCompanionBuilder,
          $$ScheduleEventsTableUpdateCompanionBuilder,
          (
            ScheduleDbEntity,
            BaseReferences<
              _$AppDatabase,
              $ScheduleEventsTable,
              ScheduleDbEntity
            >,
          ),
          ScheduleDbEntity,
          PrefetchHooks Function()
        > {
  $$ScheduleEventsTableTableManager(
    _$AppDatabase db,
    $ScheduleEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduleEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduleEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> dayWeek = const Value.absent(),
                Value<String> startTime = const Value.absent(),
                Value<String> endTime = const Value.absent(),
                Value<int> numberPair = const Value.absent(),
                Value<String> discipline = const Value.absent(),
                Value<String?> groupType = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> classroom = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<String?> urlOnline = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<List<Teacher>> teachers = const Value.absent(),
              }) => ScheduleEventsCompanion(
                id: id,
                date: date,
                dayWeek: dayWeek,
                startTime: startTime,
                endTime: endTime,
                numberPair: numberPair,
                discipline: discipline,
                groupType: groupType,
                address: address,
                classroom: classroom,
                comment: comment,
                place: place,
                urlOnline: urlOnline,
                groupName: groupName,
                code: code,
                color: color,
                teachers: teachers,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                required String dayWeek,
                required String startTime,
                required String endTime,
                required int numberPair,
                required String discipline,
                Value<String?> groupType = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> classroom = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<String?> urlOnline = const Value.absent(),
                required String groupName,
                Value<String?> code = const Value.absent(),
                Value<String?> color = const Value.absent(),
                required List<Teacher> teachers,
              }) => ScheduleEventsCompanion.insert(
                id: id,
                date: date,
                dayWeek: dayWeek,
                startTime: startTime,
                endTime: endTime,
                numberPair: numberPair,
                discipline: discipline,
                groupType: groupType,
                address: address,
                classroom: classroom,
                comment: comment,
                place: place,
                urlOnline: urlOnline,
                groupName: groupName,
                code: code,
                color: color,
                teachers: teachers,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduleEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduleEventsTable,
      ScheduleDbEntity,
      $$ScheduleEventsTableFilterComposer,
      $$ScheduleEventsTableOrderingComposer,
      $$ScheduleEventsTableAnnotationComposer,
      $$ScheduleEventsTableCreateCompanionBuilder,
      $$ScheduleEventsTableUpdateCompanionBuilder,
      (
        ScheduleDbEntity,
        BaseReferences<_$AppDatabase, $ScheduleEventsTable, ScheduleDbEntity>,
      ),
      ScheduleDbEntity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScheduleEventsTableTableManager get scheduleEvents =>
      $$ScheduleEventsTableTableManager(_db, _db.scheduleEvents);
}
