// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_core_calendar_action_events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleCoreCalendarActionEvents _$MoodleCoreCalendarActionEventsFromJson(
        Map<String, dynamic> json) =>
    MoodleCoreCalendarActionEvents(
      events: (json['events'] as List<dynamic>?)
              ?.map(
                  (e) => MoodleActionEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastid: (json['lastid'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MoodleCoreCalendarActionEventsToJson(
        MoodleCoreCalendarActionEvents instance) =>
    <String, dynamic>{
      'events': instance.events.map((e) => e.toJson()).toList(),
      'lastid': instance.lastid,
    };

MoodleActionEvent _$MoodleActionEventFromJson(Map<String, dynamic> json) =>
    MoodleActionEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      activityname: json['activityname'] as String?,
      modulename: json['modulename'] as String?,
      instance: (json['instance'] as num?)?.toInt(),
      timesort: (json['timesort'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
      course: json['course'] == null
          ? null
          : MoodleActionEventCourse.fromJson(
              json['course'] as Map<String, dynamic>),
      action: json['action'] == null
          ? null
          : MoodleActionEventAction.fromJson(
              json['action'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MoodleActionEventToJson(MoodleActionEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'activityname': instance.activityname,
      'modulename': instance.modulename,
      'instance': instance.instance,
      'timesort': instance.timesort,
      'url': instance.url,
      'course': instance.course?.toJson(),
      'action': instance.action?.toJson(),
    };

MoodleActionEventCourse _$MoodleActionEventCourseFromJson(
        Map<String, dynamic> json) =>
    MoodleActionEventCourse(
      fullname: json['fullname'] as String? ?? '',
      shortname: json['shortname'] as String? ?? '',
      idnumber: json['idnumber'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleActionEventCourseToJson(
        MoodleActionEventCourse instance) =>
    <String, dynamic>{
      'fullname': instance.fullname,
      'shortname': instance.shortname,
      'idnumber': instance.idnumber,
    };

MoodleActionEventAction _$MoodleActionEventActionFromJson(
        Map<String, dynamic> json) =>
    MoodleActionEventAction(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      actionable: json['actionable'] == null
          ? false
          : _boolFromJson(json['actionable']),
    );

Map<String, dynamic> _$MoodleActionEventActionToJson(
        MoodleActionEventAction instance) =>
    <String, dynamic>{
      'name': instance.name,
      'url': instance.url,
      'actionable': instance.actionable,
    };
