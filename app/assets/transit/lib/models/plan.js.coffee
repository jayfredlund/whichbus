class Transit.Models.Plan extends Backbone.Model
  urlRoot: '/api/otp/plan'
  defaults:
    itineraries: []
    desired_itineraries: 3

  initialize: =>
    # create a local storage for the geocode data
    @geocode_storage = Transit.storage_get('geocode')

  parse: (plan) =>
    @set
      date: new Date(plan.date)
      from: plan.from
      to: plan.to
      itineraries: new Transit.Collections.Itineraries(plan.itineraries)

  sync: (method, model, options) =>
    if method == 'read'
      $.get @url(), @request(), (response) =>
        # OTP returns status 200 for everything, so handle response manually
        if response.error?
          options.error response.error.msg
        else options.success response.plan
    else options.error 'Plan is read-only.'

  request: =>
    date: @get('date').toDateString()
    time: @get('date').toTimeString()
    fromPlace: "#{@get('from').lat},#{@get('from').lon}"
    toPlace: "#{@get('to').lat},#{@get('to').lon}"
    numItineraries: @get('desired_itineraries')

  geocode: (query, callback) ->
    # retrieve the location from the local storage if possible
    if @geocode_storage[query]?
      callback(@geocode_storage[query])
    else
      bounds = Transit.map.leaflet?.getBounds()
      $.get 'http://open.mapquestapi.com/nominatim/v1/search'
        format: 'json'
        countrycodes: 'US'
        viewbox: bounds?.toBBoxString()
        q: query
      .success (response) =>
        # save the query in the local storage
        @geocode_storage[query] = response
        Transit.storage_set('geocode', @geocode_storage)
        callback(response)
      .error ->
        console.log "Failed to geocode #{query}."

  geocode_from_to: (from_query, to_query) =>
    # TODO: It would be nice to batch this instead of doing 2 queries.
    @geocode from_query, (from) =>
      @geocode to_query, (to) =>
        if from[0]? and to[0]?
          @set
            from: lat: from[0].lat, lon: from[0].lon
            to: lat: to[0].lat, lon: to[0].lon
          @trigger 'geocode'
        else console.log 'From and to locations required.'


  current_location: (selector, target) =>
    # TODO: Use leaflet's map.locate()
    navigator.geolocation.getCurrentPosition (pos) =>
      latitude = pos.coords.latitude.toFixed(7)
      longitude = pos.coords.longitude.toFixed(7)
      selector.val "#{latitude},#{longitude}"
      @set target, lat: latitude, lon: longitude
      @trigger 'geolocate'
