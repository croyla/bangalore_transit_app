
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  TransitStop? _start;
  TransitStop? _end;
  final MapController mapController = MapController();
  List<Polyline> _polylines = [];
  List<Marker> _markers = [for (TransitStop stop in Data.stops as List)
    Marker(point: stop.marker,
      width: 4,
      height: 4,
      child: Container(
        color: Colors.white10,
      )
    )
  ];
  Geodesy geodesy = Data.geodesy;
  /* Clear map points and lines, set _point to default */
  void _clearMap() {
    setState(() {
      _markers = [for (TransitStop stop in Data.stops as List)
        Marker(point: stop.marker,
            width: 24,
            height: 24,
            child: const Icon(
              Icons.airline_stops_sharp,
              size: 24,
              color: Colors.black,
            )
        )
      ];
      _polylines = [];
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
        _markers.add(
            Marker(
              point: _start!.marker,
              width: 7,
              height: 7,
              child: Container(
                color: Colors.green,
              )
            )
        );
        _point = 'End';
      } else if(_point == 'End') {
        _end = nearest;
        _markers.add(
            Marker(
                point: _end!.marker,
                width: 7,
                height: 7,
                child: Container(
                  color: Colors.blue,
                )
            )
        );
        _updateOnMap();
        // _polylines.add(
        //   Polyline(points: [_start!.marker, _end!.marker], color: Colors.redAccent) // TEST
        // );
        _point = 'Disabled';
      }
    });
  }
  void _updateOnMap() async {
    List<List<RouteSuggestion>> journeys = await getRoutes(3, 100, _start!, _end!); // all time is taken here
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
          if (kDebugMode) {
            print('READING SUGGESTION ${[suggestion.start.name, suggestion.end.name]} WITH ROUTES ${[for (TransitRoute lines in suggestion.lines) lines.name]}');
          }
          _markers.add(Marker(
              point: suggestion.start.marker,
              width: 7,
              height: 7,
              child: Container(
                  color: Colors.green
              )
          ));
          _markers.add(Marker(
              point: suggestion.end.marker,
              width: 7,
              height: 7,
              child: Container(
                  color: Colors.blue
              )
          ));
          _polylines.add(
              Polyline(points: // add random to see multiple different journeys
              [for(LatLng point in suggestion.polyline) LatLng(point.latitude + (random / 100000), point.longitude + (random / 100000))],
                  color: color, strokeWidth: 5)
          );
          color = Color.fromARGB(color.alpha, color.red + 5, color.green + 5, color.blue + 5);
          mapController.move(suggestion.polyline[0], mapController.camera.zoom);
        }
      }
    });
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: 80,
              child: FlutterMap(
                mapController: mapController,
                options: const MapOptions(
                  initialCenter: LatLng(12.967099, 77.587909),
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
                      ]
                  ),
                  PolylineLayer(
                      polylines: _polylines
                  ),
                  MarkerLayer(
                      markers: _markers
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
              flex: 10,
              child: CupertinoButton(
                onPressed: _setPoint,
                child: Text('Add $_point'),
              ),
            ),
            Expanded(
              flex: 10,
              child: CupertinoButton(
                onPressed: _clearMap,
                child: const Text('Clear map'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}