angular.module("admin.indexUtils").factory "dataFetcher", [
  "$http", "$q"
  ($http, $q) ->
    return (dataLocation) ->
      deferred = $q.defer()
      $http.get(dataLocation).success((data) ->
        deferred.resolve data
      ).error ->
        deferred.reject()

      deferred.promise
]
