_ = require("underscore")
ObjectID = require('mongodb').ObjectID
MongoDb = require("mongodb")
redis = require("redis")

class Database

  constructor: (app) ->
    @mongo = new MongoDb.MongoClient(new MongoDb.Server(app.get("host:mongo"), 27017));
    #@redis = redis.createClient(null, app.get("host:redis"))
    @mongo.open((err) -> if err then throw err)

class BaseController

  constructor: (@db) ->
    @db.madoka = @db.mongo.db("madoka")

class LocationsController extends BaseController

  routes: (app, root) =>
    app.get("#{root}/locations", @locations)
    app.get("#{root}/locations/:location", @location)

  locations: (req, res) =>
    @db.madoka.collection("locations").find({}, ["_id", "name", "city", "state", "address", "times", "n_anon", "tickets"]).toArray((err, items) =>
      if err?
        res.json(400, {"error":err})
        return
      res.json(items)
    )

  location: (req, res) =>
    #location = req.params.location
    @db.madoka.collection("locations").findOne({"_id":req.params.location}, (err, location) =>
      if err?
        res.json(400, {"error":err})
        return
      else if !(location?)
        res.json(404, {"error":"location not found"})
        return
      # Should really use async.js for this
      @db.madoka.collection("anons").find({"l_id":location._id}).toArray((err, anons) =>
        if err?
          res.json(400, {"error":err})
          return
        @db.madoka.collection("restaurants").find({"l_id":location._id}).toArray((err, restaurants) =>
          if err?
            res.json(400, {"error":err})
            return
          @db.madoka.collection("rides").find({"l_id":location._id}).toArray((err, rides) =>
            if err?
              res.json(400, {"error":err})
              return
            location.anons = anons
            location.restaurants = restaurants
            location.rides = rides
            res.json(location)
            return
          )
        )
      )
    )

class AnonsController extends BaseController

  routes: (app, root) =>
    app.get("#{root}/locations/:location/anons", @anons)
    app.post("#{root}/locations/:location/anons", @newAnon)
    app.get("#{root}/locations/:location/anons/:id", @getAnon)
    app.put("#{root}/locations/:location/anons/:id", @editAnon)
    app.patch("#{root}/locations/:location/anons/:id", @patchAnon)
    app.delete("#{root}/locations/:location/anons/:id", @removeAnon)

  anons: (req, res) =>
    location = req.params.location
    @db.madoka.collection("anons").find({"l_id":location._id}).toArray((err, anons) =>
      if err?
        res.json(400, {"error":err})
        return
      res.json(anons)
    )

  newAnon: (req, res) =>
    location = req.params.location
    anonData = req.body
    anonData.l_id = location
    @db.madoka.collection("locations").findOne({"_id":req.params.location}, (err, location) =>
      if err?
        res.json(400, {"error":err})
        return
      else if !(location?)
        res.json(404, {"error":"location not found"})
        return
      @db.madoka.collection("anons").insert(anonData, {safe:true}, (err, records) =>
        @db.madoka.collection("locations").update({"_id":req.params.location}, {"$inc":{"n_anon":1}}, {safe:false})
        if err?
          res.json(400, {"error": err})
          return
        res.json(records[0])
        return
      )
    )

  getAnon: (req, res) =>
    aid = new ObjectID.createFromHexString(req.params.id)
    @db.madoka.collection("anons").findOne({"_id":aid, "l_id":req.params.location}, (err, anon) =>
      if err?
        res.json(400, {"error":err})
        return
      else if !(anon?)
        res.json(404, {"error":"anon not found"})
        return
      res.json(anon)
    )

  editAnon: (req, res) =>
    aid = new ObjectID.createFromHexString(req.params.id)
    anonData = req.body
    anonData.l_id = req.params.location
    @db.madoka.collection("anons").update({"_id":aid, "l_id":req.params.location}, anonData, {safe:true}, (err) =>
      if err?
        res.json(400, {"error":err})
        return
      res.send(204)
    )

  patchAnon: (req, res) =>
    aid = new ObjectID.createFromHexString(req.params.id)
    anonData = req.body
    @db.madoka.collection("anons").update({"_id":aid, "l_id":req.params.location}, {"$set":anonData}, {safe:true}, (err) =>
      if err?
        res.json(400, {"error":err})
        return
      res.send(204)
    )

  removeAnon: (req, res) =>
    aid = new ObjectID.createFromHexString(req.params.id)
    @db.madoka.collection("anons").remove({"_id":aid, "l_id":req.params.location}, {safe:true}, (err) =>
      @db.madoka.collection("locations").update({"_id":req.params.location}, {"$inc":{"n_anon":-1}}, {safe:false})
      if err?
        res.json(400, {"error":err})
        return
      res.send(204)
    )

class RestaurantsController extends BaseController

  routes: (app, root) =>
    app.get("#{root}/locations/:location/restaurants", @restaurants)
    app.post("#{root}/locations/:location/restaurants", @newRest)
    app.get("#{root}/locations/:location/restaurants/:id", @getRest)
    app.put("#{root}/locations/:location/restaurants/:id", @editRest)
    app.patch("#{root}/locations/:location/restaurants/:id", @patchRest)
    app.delete("#{root}/locations/:location/restaurants/:id", @removeRest)
    app.get("#{root}/locations/:location/restaurants/:id/:vote", @upvote)

  restaurants: (req, res) =>
    location = req.params.location
    @db.madoka.collection("restaurants").find({"l_id":location._id}).toArray((err, restaurants) =>
      if err?
        res.json(400, {"error":err})
        return
      res.json(restaurants)
    )

  newRest: (req, res) =>
    location = req.params.location
    restData = req.body
    restData.l_id = location
    restData.up = 1
    restData.down = 0
    restData.score = @ci_lower_bound(1, 1)
    @db.madoka.collection("locations").findOne({"_id":req.params.location}, (err, location) =>
      if err?
        res.json(400, {"error":err})
        return
      else if !(location?)
        res.json(404, {"error":"location not found"})
        return
      @db.madoka.collection("restaurants").insert(restData, {safe:true}, (err, records) =>
        if err?
          res.json(400, {"error": err})
          return
        res.json(records[0])
        return
      )
    )

  getRest: (req, res) =>
    rid = new ObjectID.createFromHexString(req.params.id)
    @db.madoka.collection("restaurants").findOne({"_id":rid, "l_id":req.params.location}, (err, restaurant) =>
      if err?
        res.json(400, {"error":err})
        return
      else if !(restaurant?)
        res.json(404, {"error":"restaurant not found"})
        return
      res.json(restaurant)
    )

  editRest: (req, res) =>
    rid = new ObjectID.createFromHexString(req.params.id)
    restData = req.body
    restData.l_id = req.params.location
    @db.madoka.collection("restaurants").update({"_id":rid, "l_id":req.params.location}, restData, {safe:true}, (err) =>
      if err?
        res.json(400, {"error":err})
        return
      res.send(204)
    )

  patchRest: (req, res) =>
    rid = new ObjectID.createFromHexString(req.params.id)
    restData = req.body
    @db.madoka.collection("restaurants").update({"_id":rid, "l_id":req.params.location}, {"$set":restData}, {safe:true}, (err) =>
      if err?
        res.json(400, {"error":err})
        return
      res.send(204)
    )

  removeRest: (req, res) =>
    rid = new ObjectID.createFromHexString(req.params.id)
    @db.madoka.collection("restaurants").remove({"_id":rid, "l_id":req.params.location}, {safe:true}, (err) =>
      if err?
        res.json(400, {"error":err})
        return
      res.send(204)
      return
    )

  ci_lower_bound: (pos, n) ->
    return 0 if n is 0
    z = 1.96
    phat = 1.0 * pos / n
    return (phat + z * z / (2 * n) - z * Math.sqrt((phat * (1 - phat) + z * z / (4 * n)) / n)) / (1 + z * z / n)

  dovote: (restaurant, up, down, req,res) =>
    r =
      up: restaurant.up + up
      down: restaurant.down + down
    r.score = @ci_lower_bound(r.up, r.up+r.down)
    @db.madoka.collection("restaurants").update({"_id":restaurant._id, "l_id":req.params.location}, {"$set":r}, {safe:true}, (err) =>
      if err?
        res.json(400, {"error":err})
        return
      res.send(204)
      return
    )

  upvote: (req, res) =>
    rid = new ObjectID.createFromHexString(req.params.id)
    vt = req.params.vote
    if vt == "upvote" || vt == "up"
      up = 1
      down = if req.query.change? then -1 else 0
    else if vt == "downvote" || vt == "down"
      up = if req.query.change? then -1 else 0
      down = 1
    else
      res.json(404, {"error":"command not found"})
      return
    @db.madoka.collection("restaurants").findOne({"_id":rid, "l_id":req.params.location}, (err, restaurant) =>
      if err?
        res.json(400, {"error":err})
        return
      else if !(restaurant?)
        res.json(404, {"error":"restaurant not found"})
        return
      @dovote(restaurant, up, down,req, res)
    )

class RidesController extends BaseController

  routes: (app, root) =>
    app.get("#{root}/locations/:location/rides", @rides)
    app.post("#{root}/locations/:location/rides", @newRide)
    app.get("#{root}/locations/:location/rides/:id", @getRide)
    app.put("#{root}/locations/:location/rides/:id", @editRide)
    app.patch("#{root}/locations/:location/rides/:id", @patchRide)
    app.delete("#{root}/locations/:location/rides/:id", @removeRide)

  rides: (req, res) =>
    location = req.params.location
    @db.madoka.collection("rides").find({"l_id":location._id}).toArray((err, anons) =>
      if err?
        res.json(400, {"error":err})
        return
      res.json(anons)
    )

  newRide: (req, res) =>
    location = req.params.location
    rideData = req.body
    rideData.l_id = location
    @db.madoka.collection("locations").findOne({"_id":req.params.location}, (err, location) =>
      if err?
        res.json(400, {"error":err})
        return
      else if !(location?)
        res.json(404, {"error":"location not found"})
        return
      @db.madoka.collection("rides").insert(rideData, {safe:true}, (err, records) =>
        if err?
          res.json(400, {"error": err})
          return
        res.json(records[0])
        return
      )
    )

  getRide: (req, res) =>
    rid = new ObjectID.createFromHexString(req.params.id)
    @db.madoka.collection("rides").findOne({"_id":rid, "l_id":req.params.location}, (err, ride) =>
      if err?
        res.json(400, {"error":err})
        return
      else if !(ride?)
        res.json(404, {"error":"ride not found"})
        return
      res.json(ride)
    )

  editRide: (req, res) =>
    rid = new ObjectID.createFromHexString(req.params.id)
    rideData = req.body
    rideData.l_id = req.params.location
    @db.madoka.collection("rides").update({"_id":rid, "l_id":req.params.location}, rideData, {safe:true}, (err) =>
      if err?
        res.json(400, {"error":err})
      res.send(204)
    )

  patchRide: (req, res) =>
    rid = new ObjectID.createFromHexString(req.params.id)
    rideData = req.body
    @db.madoka.collection("rides").update({"_id":rid, "l_id":req.params.location}, {"$set":rideData}, {safe:true}, (err) =>
      if err?
        res.json(400, {"error":err})
        return
      res.send(204)
    )

  removeRide: (req, res) =>
    rid = new ObjectID.createFromHexString(req.params.id)
    @db.madoka.collection("rides").remove({"_id":rid, "l_id":req.params.location}, {safe:true}, (err) =>
      if err?
        res.json(400, {"error":err})
        return
      res.send(204)
    )

exports.routes = (app, root) ->
  db = new Database(app)
  (new LocationsController(db)).routes(app, root)
  (new AnonsController(db)).routes(app, root)
  (new RestaurantsController(db)).routes(app, root)
  (new RidesController(db)).routes(app, root)

