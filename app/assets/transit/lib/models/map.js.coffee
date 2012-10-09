class Transit.Models.Map extends Backbone.Model
  urlRoot: '/api/otp/metadata'

  defaults:
    api_url: 'http://{s}.tiles.mapbox.com/v3/mapbox.mapbox-streets/{z}/{x}/{y}.png'
    attribution: '&copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors,
    <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>,
    &copy; <a href="http://mapbox.com/">Mapbox</a>'
    fit_bounds: true

  initialize: (attributes) =>
    @leaflet = @map = new L.Map attributes.element,
      center: new L.LatLng(47.62167,-122.349072)
      zoom: 13
      maxZoom: 17
    tiles = new L.TileLayer(@get('api_url'), attribution: @get('attribution'))
    @map.attributionControl.setPrefix('')
    @map.addLayer(tiles)

    @map.addLayer @create_marker('from', new L.LatLng(0,0), Transit.Markers.Start)
    @map.addLayer @create_marker('to', new L.LatLng(0,0), Transit.Markers.End)

    @on 'change:south_west change:north_east', @set_max_bounds
    @on 'change', @update_markers
    @fetch()

  parse: (data) =>
    @set
      south_west: new L.LatLng data.lowerLeftLatitude, data.lowerLeftLongitude
      north_east: new L.LatLng data.upperRightLatitude, data.upperRightLongitude

  set_max_bounds: =>
    @map.setMaxBounds new L.LatLngBounds(@get('south_west'), @get('north_east'))

  update_marker: (attribute) =>
    marker_name = "#{attribute}_marker"
    point = new google.maps.LatLng(@get(attribute).lat, @get(attribute).lon)
    if not @has(marker_name)
      # marker hasn't been added to the map yet, create it
      @create_marker(attribute, point, Transit.Markers.Start)
    else
      # marker is already on the map, update its location
      @get(marker_name).setPosition(point)

  update_markers: =>
    # create or update markers from given coordinates
    if @hasChanged('from') or @hasChanged('to')
      @update_marker('from') if @hasChanged('from')
      @update_marker('to') if @hasChanged('to')
      # trigger a single custom event when from and/or to change
      @trigger 'change:markers'

  latlng: (param) -> 
    if param instanceof L.LatLng then param
    # create as an array [lat, lon]
    else if _.isArray param then new L.LatLng param[0], param[1]
    # or as a hash { lat:?, lon:? }
    else if _.isObject param then new L.LatLng param.lat, param.lon
    # or as two parameters latlng(lat, lon)
    else new L.LatLng(arguments[0], arguments[1] ? arguments[0])

  create_polyline: (points, color='#000', weight=5, opacity=0.8) ->
    points = decodeLine(points)
    latlngs = (new L.LatLng(point[0], point[1]) for point in points)
    new L.Polyline(latlngs, color: color, opacity: opacity, clickable: false)
  
  create_multi_polyline: (pointsArray, color) ->
    latlngs = []
    for points in pointsArray
      points = decodeLine(points)
      latlngs.push(new L.LatLng(point[0], point[1]) for point in points)
    new L.MultiPolyline(latlngs, color: color, opacity: 0.6, clickable: false)

  create_marker: (name, position, icon, draggable=true, clickable=false) ->
    marker = new L.Marker position,
      title: name
      clickable: clickable
      draggable: draggable
      icon: new icon()
    marker

  addMarker: (key, name, position, icon, draggable=true, clickable=false) ->
    marker = @create_marker(position, title: name, clickable: clickable, draggable: draggable, icon: new icon())
    @set key, marker, silent: true

    console.log "new marker: #{key} => #{name}", marker

    # update location after the drag, trigger a drag event on a drag
    marker.on 'dragstart', =>
      @trigger "drag drag:start drag:start:#{name}"
    marker.on 'dragend', =>
      # @set(name, lat: marker.getLatLng().lat, lon: marker.getLatLng().lng)
      @trigger "drag drag:end drag:end:#{name}"
    # add marker to map and model
    # @map.addLayer(marker)
    # @set "#{name}_marker", marker, silent: true
    return marker

  moveMarker: (key, position) ->
    marker = @get key
    marker.setLatLng @latlng(position)

  removeMarker: (key) ->
    marker = @get key
    if marker?
      @unset key
      @removeLayer marker
      marker

  hasMarker: (key) -> @get(key)?

  addLayer: (mapLayer) ->
    if _.isArray mapLayer
      @addLayer(item) for item in mapLayer
    else
      @map.addLayer mapLayer

  removeLayer: (mapLayer) ->
    if _.isArray mapLayer
      @removeLayer(item) for item in mapLayer
    else
      @map.removeLayer mapLayer

