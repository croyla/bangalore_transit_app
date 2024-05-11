

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:transit_app/models/routes.dart';

class TransitStop {
  final int id;
  final List<TransitRoute> routeIds;
  final String name;
  final String stopId;
  final LatLng marker;
  final Map<String, dynamic>? rawJson;
  TransitStop.fromJson(Map<String, dynamic> json, this.id):
      name = json['properties']['name'].toString(),
        stopId = json['properties']['id'].toString(),
        marker = LatLng(json['geometry']['coordinates'][1] as double, // LATITUDE
            json['geometry']['coordinates'][0] as double), // LONGITUDE
        routeIds = [],
        rawJson = json;
  const TransitStop({
    required this.id,
    required this.routeIds,
    required this.name,
    required this.stopId,
    required this.marker,
    this.rawJson,
  });
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'stopId': stopId,
      'routeIds': routeIds,
      'marker': [marker.longitude, marker.latitude], // REMEMBER SECOND LATITUDE FIRST LONGITUDE WHEN READING VALUES
    };
  }
  // Implement toString to make it easier to see information about
  // each stop when using the print statement.
  @override
  String toString() {
    return 'TransitStop{id: $id, name: $name, routeIds: ${[for (TransitRoute route in routeIds) [route.name, route.routeId]]},'
        ' stopId: $stopId, marker: $marker}';
  }

  static List<TransitStop> fromGeoJSON(Map<String, dynamic> geoJson) {
    int i = 1;
    List<TransitStop> ret = [];
    for (Map<dynamic, dynamic> feature in geoJson['features']) {
      if((feature['geometry']['type'] as String).toLowerCase() == 'point') {
        ret.add(TransitStop.fromJson(feature as Map<String, dynamic>, i));
        i++;
      }
    }
    if (kDebugMode) {
      print('TOTAL STOPS LOADED: ${i-1}');
    }
    return ret;
  }
}