
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tappable_polyline/flutter_map_tappable_polyline.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geodesy/geodesy.dart';
import 'package:transit_app/main.dart';
import 'package:transit_app/models/stops.dart';
import 'package:transit_app/routing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/routes.dart';


class HomePage extends StatefulWidget{
  const HomePage({super.key, required this.title});
final String title;

@override
State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _point = 'Start';
  String _info1 = '';
  String _info2 = '';
  double _walkingDistanceMtr = 75;
  int _maxTransfers = 1;
  TransitStop? _start;
  TransitStop? _end;
  final MapController mapController = MapController();
  final Map<TaggedPolyline, RouteSuggestion> _polylines = {};
  final Map<TaggedPolyline, List<RouteSuggestion>> _polylineJourney = {};
  final Map<Marker, TransitStop> _markers = {};
  Geodesy geodesy = Data.geodesy;
  bool _closeStop = true;
  Image? busStop;



  /* Clear map points and lines, set _point to default */
  void _clearMap() {
    Data.updateData();
    busStop ??= const Image(image: AssetImage('assets/bus-stop.png'));
    setState(() {
      _markers.clear();
      for(TransitStop stop in Data.stops){
        _markers[
        Marker(point: stop.marker,
            width: 5,
            height: 5,
            child: const Icon(
              FontAwesomeIcons.mapPin // Slows to a halt when using Image()
            )
        )
        ] = stop;
      }
      _polylines.clear();
      _polylineJourney.clear();
      _point = 'Start';
      _start = null;
      _end = null;
    });
  }



  /* capture current point, move to capture next point / render visualizations */
  void _setPoint() {
    setState(() {
      TransitStop? nearest;
      for (TransitStop stop in Data.stops){
        nearest ??= stop;
        double distance1 = geodesy.distanceBetweenTwoGeoPoints(
            mapController.camera.center, stop.marker).toDouble();
        double distance2 = geodesy.distanceBetweenTwoGeoPoints(
            mapController.camera.center, nearest.marker).toDouble();
        if((distance1 - distance2) <= 0){
          nearest = stop;
        }
      }
      if(_point == 'Start') {
        _start = nearest;
        _markers[
            Marker(
              point: _start!.marker,
              width: 20,
              height: 20,
              child: busStop!
            )
        ] = nearest!;
        _point = 'End';
      } else if(_point == 'End') {
        _end = nearest;
        _markers[
            Marker(
                point: _end!.marker,
                width: 20,
                height: 20,
                child: busStop!
            )
        ] = nearest!;
        _updateOnMap();
        // _polylines.add(
        //   Polyline(points: [_start!.marker, _end!.marker], color: Colors.redAccent) // TEST
        // );
        _point = 'Disabled';
      }
    });
  }



  void _updateOnMap() async {
    List<List<RouteSuggestion>> journeys = await getRoutes(_maxTransfers, _walkingDistanceMtr, _start!, _end!, _closeStop); // all time is taken here
    setState(() {
      if(!mounted){
        if (kDebugMode) {
          print('??? CONFUSION');
        }
      }
      _markers.clear();
      for(List<RouteSuggestion> suggestions in journeys){
        if (kDebugMode) {
          print('READING SUGGESTIONS LIST ${[for (RouteSuggestion suggestion in suggestions) [suggestion.start.name, suggestion.end.name]]}');
        }
        Color color = Colors.primaries[Random().nextInt(Colors.primaries.length)];
        int random = Random().nextInt(9);
        for(RouteSuggestion suggestion in suggestions){
          suggestion.lines.sort((TransitRoute a, TransitRoute b) => a.departures.compareTo(b.departures));
          if (kDebugMode) {
            print('READING SUGGESTION ${[suggestion.start.name, suggestion.end.name]} WITH ROUTES ${[for (TransitRoute lines in suggestion.lines) lines.name]}');
          }
          _markers[Marker(
              point: suggestion.start.marker,
              width: 20,
              height: 20,
              child: busStop!
          )] = suggestion.start;
          _markers[Marker(
              point: suggestion.end.marker,
              width: 7,
              height: 7,
              child: busStop!
          )] = suggestion.end;
          TaggedPolyline polyline = TaggedPolyline(points: // add random to see multiple different journeys
          [for(LatLng point in suggestion.polyline) LatLng(point.latitude + (random / 500000), point.longitude + (random / 500000))],
              color: color, strokeWidth: 4);
          _polylines[polyline] = suggestion;
          _polylineJourney[polyline] = suggestions;
          color = Color.lerp(color, Colors.black, 0.2)!;
        }
      }
      if(journeys.isNotEmpty) {
        mapController.move(
            journeys[0][0].start.marker, mapController.camera.zoom);
      }
    });
  }


  void polylineInfo(polylines, position) {
    // TODO: Make this better, to show information in a collapsible format and to show information on routes as well when clicked
    setState(() {
      RouteSuggestion info = _polylines[polylines[0]]!;
      _info1 = '${info.start.name} ➡️ ${info.end.name} via ${[for (TransitRoute line in (info.lines.length > 5 ? info.lines.sublist(0, 5) : info.lines)) '${line.name},']}';
      _info2 =
        '${[for (RouteSuggestion suggestion in _polylineJourney[polylines[0]]!)
          '${suggestion.start.name} #️⃣ '
              '${[for (TransitRoute line in (suggestion.lines.length > 5 ? suggestion.lines.sublist(0, 5) : suggestion.lines)) '${line.name}, ']} '
              '➡️']}' // 5 most frequent buses to prevent flooding the screen
            ' ${_polylineJourney[polylines[0]]![_polylineJourney[polylines[0]]!.length-1].end.name}';
    });
  }


  void _markerInfo(TapPosition position, LatLng location){
    Marker? toDisplay;
    for(Marker marker in _markers.keys){
      if(geodesy.distanceBetweenTwoGeoPoints(location, marker.point) < 250){
        toDisplay ??= marker;
        if(geodesy.distanceBetweenTwoGeoPoints(location, marker.point) < geodesy.distanceBetweenTwoGeoPoints(location, toDisplay.point)){
          toDisplay = marker;
        }
      }
    }
    if(toDisplay != null){
      print('${_markers[toDisplay]!.name} ${_markers[toDisplay]!.stopId} is empty? ${_markers[toDisplay]!.routeIds.isEmpty}');
      setState(() {
        _info1 = 'Stop Name: ${_markers[toDisplay]!.name}';
        _info2 = 'Routes: ${[for(TransitRoute route in _markers[toDisplay]!.routeIds) '${route.name}, ']}';
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text('Options'),
            ),
            ListTile(
              leading: Checkbox(value: _closeStop, onChanged: (value) => setState(() {
                if(value != null){
                  _closeStop = value;
                }
              })),
              title: const Text('Closer Stops Only'),
              onTap: () => setState(() {
                _closeStop = !_closeStop;
              }),
            ),
            ListTile(
              leading: Text(_walkingDistanceMtr.toString()),
              // TextField(
              //   decoration: const InputDecoration(
              //     border: UnderlineInputBorder(),
              //   ),
              //   inputFormatters: <TextInputFormatter>[
              //     FilteringTextInputFormatter.allow(RegExp(r"[0-9.]")),
              //   ],
              //   keyboardType: const TextInputType.numberWithOptions(
              //     signed: false,
              //     decimal: true,
              //   ),
              // ),
              title:  Slider(
                value: _walkingDistanceMtr,
                onChanged: (double value) => setState(() {
                  _walkingDistanceMtr = double.parse(value.toStringAsFixed(1));
                }),
                min: 0.5,
                max: 500,
                divisions: 5000,
              ),
              subtitle: const Text('Walking Distance in Meters'),
            ),
            ListTile(
              leading: Text(_maxTransfers.toString()),
              // TextField(
              //   decoration: const InputDecoration(
              //     border: UnderlineInputBorder(),
              //   ),
              //   inputFormatters: <TextInputFormatter>[
              //     FilteringTextInputFormatter.allow(RegExp(r"[0-9]")),
              //   ],
              //   keyboardType: const TextInputType.number(),
              // ),
              subtitle: const Text('Maximum Transfers'),
              title:  Slider(
                value: _maxTransfers.toDouble(),
                onChanged: (double value) => setState(() {
                  _maxTransfers = value.toInt();
                }),
                min: 0,
                max: 5,
                divisions: 6,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: 70,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  onTap: _markerInfo,
                  initialCenter: const LatLng(12.967099, 77.587909),
                  initialZoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                    userAgentPackageName: 'me.crola.transit',
                  ),
                  RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                        ),
                        TextSourceAttribution(
                          'Bus Icon by mavadee - Flaticon',
                          onTap: () => launchUrl(Uri.parse('https://www.flaticon.com/free-icons/bus-stop')),
                        )
                      ]
                  ),
                  TappablePolylineLayer(
                      polylineCulling: true,
                      pointerDistanceTolerance: 20,
                      polylines: List.from(_polylines.keys),
                    onTap: polylineInfo,
                  ),
                  MarkerLayer(
                      markers: List.from(_markers.keys)
                  ),
                  Center(
                    child: Container(
                      width: 5,
                      height: 5,
                      color: Colors.red,
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: CupertinoButton(
                onPressed: _setPoint,
                child: Text('Add $_point'),
              ),
            ),
            Expanded(
              flex: 5,
              child: CupertinoButton(
                onPressed: _clearMap,
                child: const Text('Clear map'),
              ),
            ),
            Expanded(flex: 5, child: Text(_info1)),
            Expanded(flex: 10, child: Text(_info2)),
          ],
        ),
      ),
    );
  }
}