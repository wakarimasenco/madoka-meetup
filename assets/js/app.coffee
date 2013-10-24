construct = (constructor) ->
  F = (args) ->
    return constructor.apply(this, args);
  F.prototype = constructor.prototype;

  g = () ->
    return new F(arguments);
  g.$inject = constructor.$inject
  return g


homura.modules.controllers = angular.module('homuraControllers', []);
homura.modules.controllers.controller("LocationListController", construct(homura.controllers.LocationList))
homura.modules.controllers.controller("LocationController", construct(homura.controllers.LocationController))

homura.madoka = angular.module('homura-meetup', [
  'ngRoute',
  'ngResource'
  'homuraControllers'
]);


homura.madoka.config construct(homura.app)