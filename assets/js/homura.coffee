window.homura =
  controllers: {}
  modules: {}
  resource: {}

class homura.app

  @$inject: ['$routeProvider', '$locationProvider', '$httpProvider']

  constructor: (@routeProvider, @locationProvider, @httpProvider) ->
    @locationProvider.html5Mode(true)
    @httpProvider.defaults.useXDomain = true;
    @httpProvider.defaults.withCredentials = true;
    delete @httpProvider.defaults.headers.common['X-Requested-With'];
    @routes()


  routes: () ->
    @routeProvider
    .when("/",
      templateUrl: "/templates/index.html",
      controller: "LocationListController",
      controllerAs: "locationlist"
    )
    .when("/:location",
      templateUrl: "/templates/location.html",
      controller: "LocationController"
      controllerAs: "location"
    )
    .otherwise({
      redirectTo: "/"
    });

class homura.controllers.LocationList
  @$inject: ['$scope', '$resource']

  constructor: (@scope, @resource) ->
    homura.resource ||= {}
    unless homura.resource.location?
      homura.resource.location = @resource("/api/v1/locations/:locationId", locationId:"@_id")
    @locations = []
    locations = homura.resource.location.query(() =>
      @locations = locations
    )

    @orderBy = "state"

  parse: (d) ->
    return moment(d).valueOf();

  urlEncode: (target) ->
    return encodeURIComponent(target);

class homura.controllers.LocationController

  @$inject: ['$scope', '$resource', '$routeParams', '$http']

  constructor: (@scope, @resource, @routeParams, @http) ->
    homura.resource ||= {}
    @anonLunch = false
    @anonDinner = false

    @isEditRest = false
    @isEditRide = false
    @restType = "lunch"
    unless homura.resource.location?
      homura.resource.location = @resource("/api/v1/locations/:locationId", locationId:"@_id")

    homura.resource.anon = @resource("/api/v1/locations/:locationId/anons/:uid", locationId: @routeParams.location, uid:"@_id")
    homura.resource.restaurant = @resource("/api/v1/locations/:locationId/restaurants/:uid", {locationId: @routeParams.location, uid:"@_id"}, {'patch': {method:'PATCH'}})
    homura.resource.ride = @resource("/api/v1/locations/:locationId/rides/:uid", {locationId: @routeParams.location, uid:"@_id"}, {'patch': {method:'PATCH'}})


    @location = homura.resource.location.get({locationId:@routeParams.location})

  addAnon: (event) ->
    data =
      email: @anonEmail
      age: @anonAge
      lunch: @anonLunch
      dinner: @anonDinner
      misc: @anonMisc

    anon = new homura.resource.anon(data);
    anon.$save();
    @location.anons ||= []
    @location.anons.push(anon)

    @anonEmail = ""
    @anonAge = ""
    @anonLunch = false
    @anonDinner = false
    @anonMisc = ""

  removeAnon: (anon) ->
    anon = new homura.resource.anon(anon);
    anon.$remove();
    @location.anons = _.filter(@location.anons, (a) -> return anon._id != a._id)

  addRestaurant: () ->
    data =
      name: @restName
      misc: @restMisc
      ftype: @restType

    restaurant = new homura.resource.restaurant(data);
    restaurant.$save({}, () -> localStorage.setItem(restaurant._id, 1))
    @location.restaurants ||= []
    @location.restaurants.push(restaurant)

    @restName = ""
    @restMisc = ""
    @restType = ""

  doEditRest: (rest) ->
    @isEditRest = rest
    @restName = rest.name
    @restMisc = rest.misc
    @restType = rest.ftype

  editRestaurant: () ->
    data =
      name: @restName
      misc: @restMisc
      ftype: @restType

    restaurant = new homura.resource.restaurant(data);
    restaurant.$patch({ uid: @isEditRest._id});
    _.extend(@isEditRest, data)

    @isEditRest = false
    @restName = ""
    @restMisc = ""
    @restType = ""

  isUp: (rest) ->
    v = localStorage.getItem(rest._id);
    if v? && (v == "1" || v == 1)
      return true
    else
      return false

  isDown: (rest) ->
    v = localStorage.getItem(rest._id);
    if v? && (v == "-1" || v == -1)
      return true
    else
      return false

  doVote: (rest, val) ->
    vote = if val == "1" || val == 1 then "up" else "down"
    if val == 1 && @isUp(rest)
      return
    if val == -1 && @isDown(rest)
      return
    change = null
    if (val == 1 && @isDown(rest)) || (val == -1 && @isUp(rest))
      console.log ("change is true")
      change = "1"
    @http(
        method: "GET"
        url: "/api/v1/locations/#{@routeParams.location}/restaurants/#{rest._id}/#{vote}"
        params:
          change: change
    ).success((data, status, headers, config) ->
      localStorage.setItem(rest._id, val)
    )

  removeRestaurant: (rest) ->
    restaurant = new homura.resource.restaurant(rest);
    restaurant.$remove();
    @location.restaurants = _.filter(@location.restaurants, (r) -> return restaurant._id != r._id)

  addRide: () ->
    data =
      email: @rideEmail
      location: @rideLoc
      capacity: @rideCap
      misc: @rideMisc

    ride = new homura.resource.ride(data);
    ride.$save()
    @location.rides ||= []
    @location.rides.push(ride)

    @rideEmail = ""
    @rideLoc = ""
    @rideCap = ""
    @rideMisc = ""

  doEditRide: (ride) ->
    @isEditRide = ride
    @rideEmail = ride.email
    @rideLoc = ride.location
    @rideCap = ride.capacity
    @rideMisc = ride.misc

  editRide: () ->
    data =
      email: @rideEmail
      location: @rideLoc
      capacity: @rideCap
      misc: @rideMisc

    ride = new homura.resource.ride(data);
    ride.$patch({ uid: @isEditRide._id});
    _.extend(@isEditRide, data)

    @isEditRide = false
    @rideEmail = ""
    @rideLoc = ""
    @rideCap = ""
    @rideMisc = ""


  removeRide: (ride) ->
    ride = new homura.resource.ride(ride);
    ride.$remove();
    @location.rides = _.filter(@location.rides, (r) -> return ride._id != r._id)
