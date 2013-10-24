require("fs").readdirSync("./v1").forEach((file) ->
  name = file[0..file.indexOf(".") - 1]
  if name != "index"
    module = require("./" + name)
    if module.name?
      exports[module.name] = module
    else
      exports[name] = module
)

exports.routes = (app) ->
  for module of exports
    if exports[module].routes? and typeof(exports[module].routes) == "function"
      exports[module].routes(app, "/api/v1")