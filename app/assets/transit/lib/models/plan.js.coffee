class Transit.Models.Plan extends Backbone.Model
  urlRoot: '/api/otp/plan'
  defaults:
    numItineraries: 3
    arriveBy: false
    modes: ['TRANSIT','WALK']
    optimize: 'QUICK'

  defaultOptions:
    maxWalkDistance: 1200
    transferPenalty: 300
    maxTransfers: 1
    # reverseOptimizeOnTheFly: true
    showIntermediateStops: true

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
      @req = $.get @url(), @request(), (response) =>
        clearTimeout @time
        # OTP returns status 200 for everything, so handle response manually
        if response.error?
          options.error response.error.msg
        else options.success response.plan
      @time = setTimeout (=> @trigger('plan:timeout')), 7000
    else options.error 'Plan is read-only.'

  request: => $.extend {}, @defaultOptions,
    date: Transit.format_otp_date(@get('date'))
    time: Transit.format_otp_time(@get('date'))
    arriveBy: @get('arrive_by')
    mode: @get('modes').join()
    optimize: @get('optimize')
    fromPlace: "#{@get('from').lat},#{@get('from').lon}"
    toPlace: "#{@get('to').lat},#{@get('to').lon}"
    numItineraries: @get('desired_itineraries')

  geocode_from_to: (from_query, to_query) =>
    # TODO: It would be nice to batch this instead of doing 2 queries.
    Transit.Geocode.lookup
      query: Transit.unescape(from_query)
      modal: true
      success: (from) =>
        Transit.Geocode.lookup
          query: Transit.unescape(to_query)
          modal: true
          success: (to) =>
            # geocode method returns one result instead of array
            if from? and to?
              @set
                from: from 
                to: to 
              @trigger 'geocode'
            else 
              message = ""
              message += "<p>Is \"#{from_query}\" a real place?</p>" unless from?
              message += "<p>Does \"#{to_query}\" actually exist?</p>" unless to?
              message += Transit.Errors.AddressFail
              @trigger 'geocode:error', message, { from: not from, to: not to }


  current_location: (selector, target) =>
    # TODO: Use leaflet's map.locate()
    navigator.geolocation.getCurrentPosition (pos) =>
      latitude = pos.coords.latitude.toFixed(7)
      longitude = pos.coords.longitude.toFixed(7)
      selector.val "#{latitude},#{longitude}"
      @set target, lat: latitude, lon: longitude
      @trigger 'geolocate'
