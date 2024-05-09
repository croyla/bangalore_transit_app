# bangalore_transit_app

A highly unoptimized unusable application built in flutter. The goal of this application is to find all possible (metro / bus) lines and transfers from point a to point b. It is not optimised and needs to be tweaked to be used on a functional basis.

 - Data for BMTC from [Vonter github repo](https://github.com/Vonter/open-bmtc)
 - Data for Namma Metro (BMRCL) from [geohacker github repo](https://github.com/geohacker/namma-metro?)

# To-Do
### (in no particular order)
 - [ ] Asynchronously update search results to map widget
 - [ ] Add widgets to modify walking distance parameter, max transfers parameter, etc.
 - [ ] Implement a database for data storage as opposed to the current (always reading from) geojson implementation
 - [ ] Modify metro data to be able to be parsed correctly by application
 - [ ] Display information like line names, stop names on the map (using tappable polylines or popup markers)
 - [ ] Store timing information where available to display as well
 - [ ] SIFT THROUGH AND CLEAN GTFS DATA!!!
