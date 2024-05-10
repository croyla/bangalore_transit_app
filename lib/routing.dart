// Contains routing methods and functions, assume all stops in 50 meter radius are the same
// transfers and multiple routes to be shown in different colors
// for example from Vajarahalli Station to Gottigere would show a polyline
// from Vajarahalli to Konanakunte Cross in x color
// which upon clicking shows the different bus names and the metro line
// And a second polyline in y color from Konanakunte cross to Gottigere which similarly
// shows the various bus names travelling on that polyline

// Each point to point directions (with transfers) is a list of routesuggestions
// Each routesuggestion is a stop to stop polyline with buses along that route (no transfers)

import 'package:collection/collection.dart'; // was used for list.average, might need later too
import 'package:flutter/foundation.dart';
import 'package:geodesy/geodesy.dart';
import 'package:transit_app/models/stops.dart';

import 'main.dart';
import 'models/routes.dart';

Geodesy geodesy = Data.geodesy;

RouteSuggestion? createSuggestion(TransitStop start, TransitStop end, List<TransitRoute> routes){ // Polyline generation from TransitRoute polyline
  List<LatLng> routePolyline = routes[0].polyline;
  if (kDebugMode) {
    print('ROUTEPOLYLINE SIZE ${routePolyline.length}');
    print('SUGGESTION CREATION ${start.name} ➡️➡️ ${end.name}');
  }
  LatLng? nearestStart;
  LatLng? nearestEnd;
  for(LatLng point in routePolyline){
    nearestStart ??= point;
    nearestEnd ??= point;
    double distance1 = geodesy.distanceBetweenTwoGeoPoints(
        start.marker, point).toDouble();
    double distance2 = geodesy.distanceBetweenTwoGeoPoints(
        start.marker, nearestStart).toDouble();
    if((distance1 - distance2) <= 0){
      nearestStart = point;
    }
    distance1 = geodesy.distanceBetweenTwoGeoPoints(
        end.marker, point).toDouble();
    distance2 = geodesy.distanceBetweenTwoGeoPoints(
        end.marker, nearestEnd).toDouble();
    if((distance1 - distance2) <= 0){
      nearestEnd = point;
    }
  }
  if(
  (routePolyline.indexOf(nearestStart!) > routePolyline.indexOf(nearestEnd!)) ||
      (geodesy.distanceBetweenTwoGeoPoints(nearestStart, start.marker) > 400) || // leniency of 400 meters in case polyline is inaccurate
      (geodesy.distanceBetweenTwoGeoPoints(nearestEnd, end.marker) > 400)){
    if(geodesy.distanceBetweenTwoGeoPoints(nearestStart, start.marker) > 400) {
      routes[0].stopIds.remove(start);
      start.routeIds.remove(routes[0]);
    }
    if(geodesy.distanceBetweenTwoGeoPoints(nearestEnd, start.marker) > 400) {
      routes[0].stopIds.remove(end);
      end.routeIds.remove(routes[0]);
    }

    if(routes.length > 1){
      return createSuggestion(start, end, routes.sublist(1)); // trim by one
    }
    return null; // return null none found
  }
  List<LatLng> suggestionPolyline = routePolyline.sublist(routePolyline.indexOf(nearestStart), routePolyline.indexOf(nearestEnd));
  suggestionPolyline.insert(0, start.marker);
  suggestionPolyline.add(end.marker);
  return RouteSuggestion(polyline: suggestionPolyline,
      lines: routes,
      start: start,
      end: end);
  // currently inaccurate with multiple TransitRoutes that go to same stop from different polylines, need to improve
}

Future<List<List<RouteSuggestion>>> getRoutes(int maxTransfers, double walkingDistance, TransitStop start, TransitStop end) async {
  List<TransitStop> ends = getNearbyStops(walkingDistance, end);
  List<TransitStop> starts = getNearbyStops(walkingDistance, start);
  Map<TransitStop, Map<TransitStop,RouteSuggestion>> lines = {}; // first dimension start and second dimension stop
  void addLine(TransitStop start, TransitStop end, TransitRoute route){
    if (kDebugMode) {
      print('addLine called');
    }
    if (lines.containsKey(start)) {
      if (lines[start]!.containsKey(end)) {
        if(!lines[start]![end]!.lines.contains(route)) {
          lines[start]![end]!.lines.add(route);
        }
      } else {
        RouteSuggestion? suggestion = createSuggestion(start, end, [route]);
        if(suggestion != null) {
          lines[start]![end] = suggestion;
        } else {
          if (kDebugMode) {
            print('returned suggestion was null');
          }
        }
      }
    } else {
      lines[start] ??= {};
      RouteSuggestion? suggestion = createSuggestion(start, end, [route]);
      if(suggestion != null) {
        lines[start]![end] = suggestion;
      } else {
        if (kDebugMode) {
          print('returned suggestion was null');
        }
      }
      // MAKE  ROUTE SUGGESTION CREATION METHOD AND CALL HERE
    }

  }
  for (TransitStop start in starts){ // if ends.length or ends.stop.routeIds is less than starts then loop through ends and generate route backwards
    if (kDebugMode) {
      print('CURRENT START STOP ${start.name}, ${start.stopId}\n\n\n');
    }
    if(ends.contains(start)){
      if (kDebugMode) {
        print('START STOP IS END STOP, SKIPPING');
      }
      continue;
    }
    if(maxTransfers > 0){
      Map<TransitStop, int> checked = {};
      void recursiveSearch(int transferCount, TransitStop currentStop, TransitRoute? previousRoute, Map<TransitStop, List<dynamic>>? transferLine){ // List<dynamic> is [transitstop, transitroute]
        int maxTransferPossible = maxTransfers - transferCount;
        transferLine ??= {};
        if(checked.containsKey(currentStop) && checked[currentStop]! >= maxTransferPossible){
          return; // already checked this stop with a greater or equivalent maxTransferPossible
        }
        else if(maxTransferPossible <= 0){
          return; // exhausted transfer limit
        }
        else if(ends.contains(currentStop)){ // End stop reached, now construct route
          // Got to generate from transferLine
          List<TransitStop> line = [];
          Map<TransitStop, TransitRoute> lineRoute = {};
          TransitStop? current = currentStop;
          line.add(current); // destination stop added
          while(!line.contains(start)){ // now work backwards and add the stops with their routes
            if(transferLine.containsKey(current)) {
              TransitStop next = transferLine[current]![0];
              line.add(next);
              lineRoute[next] = transferLine[current]![1];
              print('${next.name} ➡️ ${lineRoute[next]?.name} ➡️ ${current?.name}');
              current = next;
            } else {
              break;
            }
          }
          current = null;
          for(TransitStop stop in line.reversed){
            if(current != null && lineRoute[current] != null){
              addLine(current, stop, lineRoute[current]!); // TODO: Somehow asynchronously update map with info from here, while allowing the multiple bus lines this way allows
            }
            current = stop;
            if(lineRoute[stop] == null) {
              if (kDebugMode) {
                print('ISSUE AT STOP ${stop.name}');
              }
            }
          }
          return;
        }
        checked[currentStop] = maxTransferPossible;
        // getNearbyStops loop here, encapsulating it all
        for(TransitRoute route in currentStop.routeIds){ // all routes coming to stop
          for(TransitStop stop in route.stopIds){ // all stops on route
            if(route.stopIds.indexOf(stop) > route.stopIds.indexOf(currentStop)){ // Only stops after this stop should be considered in route
              Map<TransitStop, List<dynamic>> transferLine2 = Map.from(transferLine); // duplicate the list to avoid modifications in different branches of recursion messing with each other
              if(route != previousRoute){ // first stop its route != null
                transferLine2[stop] = [currentStop, route]; // Store parent stops, to make RouteSuggestion generation easier when [stop] is end of journey
              } else if(route.stopIds.contains(start)){
                transferLine2.clear(); // empty map, previous keys are irrelevant
                transferLine2[stop] = [start, route]; // currentStop may end up being a direct route
              } else {
                transferLine2[stop] = transferLine2[currentStop]!; // last transfer taken, causes lots of unnecessary unused transferLine.keys
              }
              recursiveSearch(transferCount+1, stop, route, transferLine2);
              for(TransitStop nearby in getNearbyStops(walkingDistance, stop)){
                if(nearby == stop){
                  continue;
                }
                // print('Near ${stop.name} is ${nearby.name}');
                transferLine2[nearby] = [stop,
                  TransitRoute(id: -1, stopIds: [stop, nearby], name: 'Walk ${stop.name} ➡ ${nearby.name}', routeId: 'walk', polyline: [
                    stop.marker, geodesy.midPointBetweenTwoGeoPoints(stop.marker, nearby.marker), nearby.marker])];
                recursiveSearch(transferCount+1, nearby, route, transferLine2);
              }
            }
          }
        }
      } // recursiveSearch
      recursiveSearch(-1, start, null, null);
    } else {
      for(TransitRoute route in start.routeIds) {
        for (TransitStop end in ends) {
          if(route.stopIds.contains(end)){
            addLine(start, end, route);
          }
        }
      }
    }
  }
  List<List<RouteSuggestion>> suggestions = [];
  void compileLines(List<RouteSuggestion> currentLine, TransitStop? previousStop, TransitStop currentStop){
    if(lines.keys.contains(previousStop)) { // try with null? will add null safety if needed
      if(lines[previousStop]!.keys.contains(currentStop)) { // better be safe :P
        currentLine.add(lines[previousStop]![currentStop]!);
      }
    }
    if(ends.contains(currentStop)){
      suggestions.add(currentLine);
    }
     else if(lines.keys.contains(currentStop)){
      for(TransitStop stop in lines[currentStop]!.keys){
        compileLines(List.from(currentLine, growable: true), currentStop, stop);
      }
    } else{
       if (kDebugMode) {
         print('FACING ISSUE $lines');
       }
    }
  }
  for(TransitStop stop in starts){
    compileLines([], null, stop);
  }
  return suggestions;
}
Map<TransitStop, List<TransitStop>> nearbyStops = {}; // if distance changes midway, app is fucked... need to improve... optionally nuke this when distance value changes?
// Then dont take distance in method, instead define it as a variable / sharedpref option?
List<TransitStop> getNearbyStops(double distance, TransitStop stop){
  if(nearbyStops.containsKey(stop)){
    return nearbyStops[stop]!;
  }
  List<TransitStop> nearby = [stop];
  for(TransitStop dataStop in Data.stops){
    if(dataStop == stop){
      continue;
    }
    if(distance >= geodesy.distanceBetweenTwoGeoPoints(stop.marker, dataStop.marker)){
      nearby.add(dataStop);
    }
  }
  nearbyStops[stop] = nearby;
  return nearby;
}