_ = require 'lodash'
mimemessage = require 'mimemessage'
Promise = require 'bluebird'
request  = Promise.promisify(require 'request')
Promise.promisifyAll(request)

buildReq = (req) ->
  # This is a normal request
  if req.url?
    req['Content-Transfer-Encoding'] = 'binary'
    if req.body?
      req['Content-Type'] = 'application/json'
      b = JSON.stringify(req.body)
    else
      req['Content-Type'] = 'application/http'
      b = ''
    req.body = req.url + ' HTTP/1.1' + '\r\n' + b
    return _.omit(req, 'url')

  # This is a changeset
  else
    if !_.isArray req.body then throw new Error('body must be an array in changesets')
    cs = mimemessage.factory {contentType: 'multipart/mixed', body: []}
    cs.body = _.map req.body, (b) =>
      newReq = mimemessage.factory buildReq b
      return setProperHeaders b, newReq
    req.body = cs.toString()
    return req

setProperHeaders = (src, dst) ->
  for h of src
    if h == 'body' then continue
    if h == 'url'  then continue
    else
      dst.header h, src[h]
  return dst

module.exports = runBatch = (url, data) ->
  config =
    method: 'POST'
    headers:
      'Content-Type': 'multipart/mixed'
    url: url
    json: true
    multipart:
      chunked: false
      # data must be cloned here as map mutates the original array in this case
      data: _.map (_.cloneDeep data), buildReq
  request config
  .then (res) ->
    return res


#
