mimemessage = require 'mimemessage'
Promise = require 'bluebird'
utils = require 'lodash'
request = Promise.promisify(require 'request')

module.exports = runBatch = (url, data) ->
	compiledData = compileBatch(data)
	multipartHeader = compiledData.header('Content-Type')

	params =
		method: 'POST'
		url: url + '$batch'
		body: compiledData.toString({ noHeaders: true })
		json: false
		headers:
			'Content-Type': multipartHeader

	request(params)
	.then (res) ->
		return res.body

compileBatch = (data) ->
	if !utils.isArray(data)
		throw new Error('Batch must be passed an array')

	buildReq = (req) =>
		# This is a changeset
		if utils.isArray(req)
			csBody =
				for cs in req
					buildReq(cs)

			return mimemessage.factory(
				contentType: 'multipart/mixed'
				body: csBody
			)
		# This is a normal request
		else
			contentTransferEncoding = 'binary'
			if req.body?
				contentType = 'application/json'
				b = JSON.stringify(req.body)
			else
				contentType = 'application/http'
				b = ''

			newReq = mimemessage.factory({
				contentType: contentType
				contentTransferEncoding: contentTransferEncoding
				body: "#{req.method} #{req.url} HTTP/1.1\r\n#{b}"
			})
			for own option, value of req.headers
				newReq.header(option, value)

			return newReq

	batchBody =
		for req in data
			buildReq(req)

	return mimemessage.factory(
		contentType: 'multipart/mixed'
		body: batchBody
	)
