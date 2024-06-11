
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
  Row routeInfoRow = const Row();
  OverlayEntry? informationOverlay;



  /* Clear map points and lines, set _point to default */
  void _clearMap() {
    Data.updateData();
    busStop ??= const Image(image: AssetImage('assets/bus-stop.png'));
    busStop == null ? busStop = Image.asset('assets/bus-stop.png') : busStop = busStop;
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
              width: 50,
              height: 50,
              child: busStop!
            )
        ] = nearest!;
        _point = 'End';
        if(informationOverlay != null){
          createStopOverlay(_start!);
        }
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
        if(informationOverlay != null){
          createStopOverlay(_end!);
        }
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
    removeOverlay();
    setState(() {
      assert(mounted);
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
              width: 50,
              height: 50,
              child: busStop!
          )] = suggestion.start;
          _markers[Marker(
              point: suggestion.end.marker,
              width: 50,
              height: 50,
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
        createJourneyOverlay(journeys[0], journeys[0][0]);
      }
    });
  }


  void polylineInfo(polylines, position) {
    createJourneyOverlay(_polylineJourney[polylines[0]]!, _polylines[polylines[0]]!);
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
      createStopOverlay(_markers[toDisplay]!);
    }
  }


  void removeOverlay(){
    informationOverlay?.remove();
    informationOverlay?.dispose();
    informationOverlay = null;
  }

  void createStopOverlay(TransitStop stop){
    mapController.move(stop.marker, mapController.camera.zoom);
    removeOverlay();
    assert(informationOverlay == null);
    informationOverlay = OverlayEntry(builder: (BuildContext context) {
      return Container(
        padding: const EdgeInsets.only(left: 50.0, right: 50.0, top: 50, bottom: 50),
        child: Card(
          elevation: 3.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: removeOverlay,
                      style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('❌'),
                    ),

                    Text('${stop.name} (${stop.stopId})'),
                    TextButton(
                      onPressed: _setPoint,
                      child: Text('Add $_point'),
                    ),
                  ],
                ),
              ])
              ),

              Expanded(child:
              ListView(
                scrollDirection: Axis.vertical,
                    children: [
                    for (TransitRoute route in stop.routeIds)
                      Container(
                        decoration: BoxDecoration(
                            border:
                            Border.all(
                                color: Colors.deepPurpleAccent
                            )
                        ),
                        child:
                        Wrap(

                          alignment: WrapAlignment.start,
                          children: [
                            TextButton(
                                onPressed: () => createRouteOverlay(route),
                                child: Text(route.name)
                            ),
                            const Text(' to '),
                            TextButton(
                                onPressed: () => createStopOverlay(route.stopIds[route.stopIds.length-1]),
                                child: Text(route.stopIds[route.stopIds.length-1].name)
                            ),
                          ],
                        ),
                      )

                    ],
                  ),
        )
            ],
          ),
        ),
      );
    });
    Overlay.of(context).insert(informationOverlay!);
  }

  void createRouteOverlay(TransitRoute route){
    removeOverlay();
    assert(informationOverlay == null);
    informationOverlay = OverlayEntry(builder: (BuildContext context) {
      return Container(
        padding: const EdgeInsets.only(left: 50.0, right: 50.0, top: 50, bottom: 50),
        child: Card(
          elevation: 3.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: removeOverlay,
                  style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text('❌'),
                ),
                Text('${route.id}. ${route.name} ${route.stopIds[0].name} -> ${route.stopIds[route.stopIds.length-1].name} ${route.routeId}')
              ],
            ),

          ]
          )
          ),
              const SizedBox(height: 10),
              Expanded(child:
              ListView(
                scrollDirection: Axis.vertical,
                children: [
                  for (TransitStop stop in route.stopIds)
                    Wrap(
                      alignment: WrapAlignment.start,
                      children: [
                        TextButton(
                            onPressed: () => createStopOverlay(stop),
                            child: Text('${route.stopIds.indexOf(stop)+1}. ${stop.name}')
                        ),
                      ],
                    ),
                ],
              ),
              )
            ],
          ),
        ),
      );
    });
    Overlay.of(context).insert(informationOverlay!);
  }

  void createJourneysOverlay({List<RouteSuggestion>? highlighted}){
    removeOverlay();
    assert(informationOverlay == null);
    List<Wrap> widgets = [];
    for(List<RouteSuggestion> journey in _polylineJourney.values){
      widgets.add(
          Wrap(
            alignment: WrapAlignment.start,
            children: [
            for(RouteSuggestion suggestion in journey)
              journey == highlighted ?
              TextButton(
                  onPressed: () => createJourneyOverlay(journey, suggestion),
                  style: TextButton.styleFrom(backgroundColor: Colors.indigoAccent.withOpacity(0.15)),
                  child: Text('${suggestion.start.name} to ${suggestion.end.name}')
              )
                  :
              TextButton(
                onPressed: () => createJourneyOverlay(journey, suggestion),
                child: Text('${suggestion.start.name} to ${suggestion.end.name}')
              )
          ]
      ));
    }
    informationOverlay = OverlayEntry(builder: (BuildContext context) {
      return Container(
        padding: const EdgeInsets.only(left: 50.0, right: 50.0, top: 50, bottom: 50),
        child: Card(
          elevation: 3.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: removeOverlay,
                      style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('❌'),
                    ),
                    const Text('All Routes')
                  ],
                ),

              ]
              )
              ),
              const SizedBox(height: 10),
              Expanded(child:
              ListView(
                scrollDirection: Axis.vertical, children: widgets,
              ),
              )
            ],
          ),
        ),
      );
    });
    Overlay.of(context).insert(informationOverlay!);
  }
  
  void createJourneyOverlay(List<RouteSuggestion> suggestions, RouteSuggestion primary){
    removeOverlay();
    assert(informationOverlay == null);
    informationOverlay = OverlayEntry(builder: (BuildContext context) {
      return Container(
        padding: const EdgeInsets.only(left: 50.0, right: 50.0, top: 50, bottom: 50),
        child:
          Card(
            elevation: 3.0,
            child:
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 50, child:
                      ListView(
                        scrollDirection: Axis.horizontal,

                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            TextButton(
                              onPressed: removeOverlay,
                              style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              child: const Text('❌'),

                            ),
                            TextButton(onPressed: () => createStopOverlay(primary.start), child: Text(primary.start.name)),
                            const Text(' to '),
                            TextButton(onPressed: () => createStopOverlay(primary.end), child: Text(primary.end.name)),
                            TextButton(
                                onPressed: () => createJourneysOverlay(highlighted: suggestions), 
                                style: TextButton.styleFrom(backgroundColor: Colors.greenAccent), 
                                child: const Text('Show All Routes'),
                            ),
                          ],
                          ),
                        ],
                      ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(height: 50, child:
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child:
                          ListView(scrollDirection: Axis.horizontal, children: [
                            for(RouteSuggestion suggestion in suggestions)
                              suggestion == primary ?
                              TextButton(
                                  onPressed: () => createJourneyOverlay(suggestions, suggestion),
                                  style: TextButton.styleFrom(backgroundColor: Colors.amber),
                                  child: Text('${suggestions.indexOf(suggestion)+1}. ${suggestion.start.name} to ${suggestion.end.name}')
                              ) :
                              TextButton(
                                  onPressed: () => createJourneyOverlay(suggestions, suggestion),
                                  child: Text('${suggestions.indexOf(suggestion)+1}. ${suggestion.start.name} to ${suggestion.end.name}')
                              )
                          ],
                          )
                        )

                      ]
                    ),
                  ),
                  Expanded(child:
                    ListView(
                        scrollDirection: Axis.vertical,
                        children: [
                          for (TransitRoute route in primary.lines)
                            Wrap(
                              alignment: WrapAlignment.start,
                              children: [
                                TextButton(
                                    onPressed: () => createRouteOverlay(route),
                                    child: Text('${primary.lines.indexOf(route)+1}. ${route.name}')
                                ),
                                const Text(' towards '),
                                TextButton(
                                    onPressed: () => createStopOverlay(route.stopIds[route.stopIds.length-1]),
                                    child: Text(route.stopIds[route.stopIds.length-1].name)
                                )
                              ],
                            ),
                        ],
                    ),
                  )
                ],
              ),
          ),
      );
    });
    Overlay.of(context, debugRequiredFor: widget).insert(informationOverlay!);

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
              leading: Text(_walkingDistanceMtr.toString()), // Make this editable
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
              flex: 85,
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