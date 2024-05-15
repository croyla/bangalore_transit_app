# bangalore_transit_app

A highly unoptimized unusable application built in flutter. The goal of this application is to find all possible (metro / bus) lines and transfers from point a to point b. It is not optimised and needs to be fiddled with to be used on a functional basis.

 - Data for BMTC from [Vonter github repo](https://github.com/Vonter/bmtc-gtfs)
 - Data for Namma Metro (BMRCL) from [geohacker github repo](https://github.com/geohacker/namma-metro?)

# To-Do
### (in no particular order)
 - [ ] Use sharedprefs for Maximum Transfers, Walking Distance
 - [ ] Prevent duplicate journeys in getRoutes
 - [ ] Use OSRM or something similar for getNearbyStops, and walk polyline
 - [ ] Implement a local database for data storage as opposed to the current (always reading from) geojson implementation
 - [ ] Modify metro data to be able to be parsed correctly by application
 - [ ] Parse geojson info into the application more accurately (relations between stops and routes are a bit goofy at the moment)
 - [ ] Store timing information where available to display as well
 - [ ] SIFT THROUGH AND CLEAN GTFS DATA!!!
