###
Module dependencies.
###

express = require("express")
redis = require("redis")

http = require("http")
path = require("path")
api =
  v1: require("./v1")
app = express()

allowCrossDomain = (req, res, next) ->
  origin = req.get("Origin")
  if origin? and origin.toLowerCase().indexOf("wakarimasen.co") != -1
    res.header('Access-Control-Allow-Origin', req.get("Origin"));
    res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
    res.header('Access-Control-Allow-Credentials', 'true');

  next();

app.configure ->

  app.set "port", process.env.PORT or 9001
  app.set "views", __dirname + "/views"
  app.set "view engine", "jade"
  app.use express.logger("dev")
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser("lbnlS6kkE2j6OGrQda9xTKiJHAUEifTuGANNjZOh")
  app.use allowCrossDomain;
  app.use app.router
  app.use require('connect-assets')()
  #app.use require("less-middleware")(src: __dirname + "/public")
  app.use express.static(path.join(__dirname, "public"))

  unless "development" is app.get("env")
    client = redis.createClient()
    activeUser = (req, res, next) ->
      client.zadd "madoka:active:uniques", (new Date).getTime(), req.ip
      next()
    app.use activeUser

require("coffee-trace")
app.configure "development", ->

  app.use express.errorHandler()
  app.set("host:mongo", "wakarimasen.co")
  app.set("host:redis", "localhost")

app.configure "production", ->
  app.use express.errorHandler()
  app.set("host:mongo", "localhost")
  app.set("host:redis", "localhost")

api.v1.routes(app)

app.get('/:location?', (req, res) -> res.render('index'));
app.get('/templates/:template', (req, res) ->
  t = req.params.template.replace(".html", ".jade")
  res.render("templates/#{t}"));


http.createServer(app).listen app.get("port"), ->
  console.log "Express server listening on port " + app.get("port")

app.use((req, res, next) ->
  res.json(404, {"error":"404"})
);

exports.app = app