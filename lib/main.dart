import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geodesy/geodesy.dart';
import 'package:transit_app/models/routes.dart';
import 'package:transit_app/models/stops.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'home.dart';


void main()  async {
  const app = MyApp();
  runApp(app);
  final stopJson = jsonDecode(await rootBundle.loadString('assets/stops.geojson')) as Map<String, dynamic>;
  final routeJson = jsonDecode(await rootBundle.loadString('assets/routes.geojson')) as Map<String, dynamic>;
  // final metroJson = jsonDecode(await rootBundle.loadString('assets/metro-lines-stations-2024-for-use.geojson')) as Map<String, dynamic>;
  List<TransitStop> stopsFromJson =  TransitStop.fromGeoJSON(stopJson);
  List<TransitRoute> routesFromJson = TransitRoute.fromGeoJSON(routeJson);
  // routesFromJson.addAll(TransitRoute.fromGeoJSON(metroJson));
  // stopsFromJson.addAll(TransitStop.fromGeoJSON(metroJson));
  // NEED TO FIX METRO DATA
  Data.routes.addAll(routesFromJson);
  Data.stops.addAll(stopsFromJson);
  Data.completeMappings();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMTC Demo :P',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'HALLO :D'),
    );
  }
}

//TEMP!! ONLY TESTING!!!
class Data {
  static List<TransitStop> stops = [];
  static List<TransitRoute> routes = [];
  static Geodesy geodesy = Geodesy();
  static void completeMappings(){
    Map<String, List<TransitStop>> stopNames = {};
    Map<String, TransitRoute> routeNames = {};
    for (TransitStop stop in stops){
      if(stopNames.containsKey(stop.name)) {
        stopNames[stop.name]?.add(stop);
      } else {
        stopNames[stop.name] = [stop];
      }
    }
    for (TransitRoute route in routes){
      routeNames.addAll({route.name: route});
      if (route.rawJson != null){
        for (String stopName in route.rawJson?['properties']['stop_list']){
          if(stopNames.containsKey(stopName)) {
            TransitStop? stopToAdd;
            for (TransitStop stop in stopNames[stopName]!) {
              if(stopToAdd != null){
                double prevDistance = 0;
                for (LatLng point in route.polyline){
                  double distance1 = geodesy.distanceBetweenTwoGeoPoints(
                    stop.marker, point).toDouble();
                  double distance2 = geodesy.distanceBetweenTwoGeoPoints(
                    stopToAdd!.marker, point).toDouble();
                  if(prevDistance < distance1 || prevDistance < distance2){
                    break;
                  }
                  if ((distance1 - distance2) <= 0) {
                    stopToAdd = stop;
                    prevDistance = distance1;
                  } else {
                    prevDistance = distance2;
                  }
                }
              } else {
                stopToAdd = stop;
              }
            }
            route.stopIds.add(stopToAdd!);
            stopToAdd.routeIds.add(route);
          } else {
            if (kDebugMode) {
              print('$stopName not found in loaded data');
            }
          }
        }
      }
    }
    // add list of routes to stops and list of stops to routes

  }
}