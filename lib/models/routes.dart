

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:transit_app/models/stops.dart';

class TransitRoute{
  final List<TransitStop> stopIds;
  final int id;
  final String name;
  final String routeId;
  final List<LatLng> polyline;
  final Map<String, dynamic>? rawJson; // used for completing mappings if built fromJson
  final int departures;
  TransitRoute.fromJson(Map<String, dynamic> json, this.id):
        name = json['properties']['name'] as String,
        routeId = '${json['properties']['id']}${json['properties']['direction_id']}',
        polyline = [for (List<dynamic> coords in
        [for (List<dynamic> t in json['geometry']['coordinates'])[t[1] as double, t[0] as double]])
          LatLng(coords[0] as double, coords[1] as double)],
        stopIds = [],
        rawJson = json,
        departures = json['properties']['trip_count'];
  const TransitRoute({
    required this.id,
    required this.stopIds,
    required this.name,
    required this.routeId,
    required this.polyline,
    this.rawJson,
    required this.departures,
  });

  // Convert a Dog into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'routeId': routeId,
      'polyline': [for (LatLng i in polyline) [i.latitude, i.longitude]],
      'stopIds': stopIds,
    };
  }
  // Implement toString to make it easier to see information about
  // each route when using the print statement.
  @override
  String toString() {
    return 'TransitRoute{id: $id, name: $name, stopIds: ${[for (TransitStop route in stopIds) [route.name, route.stopId]]},'
        ' routeId: $routeId}';
  }
  static List<TransitRoute> fromGeoJSON(Map<String, dynamic> geoJson) {
    int i = 1;
    List<TransitRoute> ret = [];
    for (Map<dynamic, dynamic> feature in geoJson['features']) {
      if((feature['geometry']['type'] as String).toLowerCase() == 'linestring') {
        ret.add(TransitRoute.fromJson(feature as Map<String, dynamic>, i));
        i++;
      }
    }
    if (kDebugMode) {
      print('TOTAL ROUTES LOADED ${i-1}');
    }
    return ret;
  }
}

class RouteSuggestion {
  final List<LatLng> polyline; // First is start stop, last is end stop
  final List<TransitRoute> lines;
  final TransitStop start;
  final TransitStop end;
  const RouteSuggestion({
    required this.polyline,
    required this.lines,
    required this.start,
    required this.end
});
  @override
  String toString() {
    return 'RouteSuggestion{lines: ${[for (TransitRoute line in lines) line.name]}, start: ${start.name}, end: ${end.name}}';
  }
}