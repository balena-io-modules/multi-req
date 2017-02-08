expect = require('chai').expect
http = require 'http'
runBatch = require './runBatch'
_ = require 'lodash'
{multiReq} = require '../lib/index.coffee'


describe 'multi-req', () ->
  uri = null
  before (done) ->
    server = createServer()
    server.listen {host: 'localhost', port: 0}, () ->
      uri = toURI server.address()
      done()

  it 'run batch and check if everything is correctly parsed', () ->
    runBatch(uri, data)
    .then (res) -> checkBody(res.body)

  it 'shuffle the body to test for race conditions', () ->
    runBatch(uri, _.shuffle(data))
    .then (res) -> checkBody(res.body)

  it 'shuffle the body to test for race conditions', () ->
    runBatch(uri, _.shuffle(data))
    .then (res) -> checkBody(res.body)

  it 'shuffle the body to test for race conditions', () ->
    runBatch(uri, _.shuffle(data))
    .then (res) -> checkBody(res.body)

checkBody = (body) ->
  expect(body).to.be.lengthOf(4)
  _.map body, (b) ->
    if b._isChangeSet
      expect(b.changeSet).to.be.lengthOf(2)
      _.map b.changeSet, (d) ->
        expect(d.headers).to.include.keys('content-id')
    else
      expect(b.headers).to.not.be.empty
      expect(b.method).to.not.be.empty
      expect(b.url).to.not.be.empty
      expect(b.data).to.be.a('object')

createServer = () ->
  return http.createServer (req, res) ->
    multiReq req, res, (err) ->
      res.statusCode = if err then (err.status || 500) else 200
      res.end(if err then err.message else JSON.stringify(req.batch))

toURI = (serverInfo) ->
  return 'http://' + serverInfo.address + ':' + serverInfo.port


dev1 =
  name: 'First'
  devtype: 'b1'

dev2 =
  name: 'Second'
  devtype: 'b2'

dev3 =
  name: 'Third'
  devtype: 'b3'

dev4 =
  name: 'Fourth'
  devtype: 'cs1'

dev5 =
  name: 'Fifth'
  devtype: 'cs2'


data = [
  {
    url: 'GET /testpine/device'
  },
  {
    url: 'POST /testpine/device'
    body: dev2
  },
  {
    url: 'POST /testpine/device'
    body: dev3
  },
  {
    body: [{
      url: 'POST /testpine/device'
      "Content-ID": "1"
      body: dev4
    },
    {
      url: 'PUT /testpine/device/$1'
      "Content-ID": 2
      body: dev5
    }]
}]
