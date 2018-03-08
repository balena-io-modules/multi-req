{ HTTPParser: parser } = require 'http-parser-js'
dicer = require 'dicer'
Readable = require 'readable-stream'
Promise = require 'bluebird'

RE_BOUNDARY = /^multipart\/.+?(?:;\s?boundary=(?:(?:"(.+)")|(?:([^\s]+))))$/i

parseInto = (dst, boundary) ->
	d = new dicer({ boundary: boundary[1] || boundary[2] })
	d.pending = []
	position = 0
	d.on 'part', (part) ->
		slot = position++
		request =
			headers: {}
			method: null
			url: null
			data: []
			body: {}
			_isChangeSet: false

		onEnd = (part) ->
			->
				dst[slot] = (part)

		part.on 'header', (header) ->
			Object.assign request.headers, header

		part.on 'data', (data) ->
			if m1 = RE_BOUNDARY.exec(request.headers['content-type']?[0])
				pend = new Promise (resolve, reject) ->
					d1 = parseInto(request.data, m1)
					finish = onEnd({ _isChangeSet: true, changeSet: request.data })
					d1.on 'finish', ->
						finish()
						resolve()
					bodyStream = new Readable()
					bodyStream.pipe(d1)
					bodyStream.push(data.toString())
					bodyStream.push(null)
				d.pending.push(pend)
			else
				part.on 'end', onEnd request
				p = new parser(parser.REQUEST)
				p.execute(data)
				p.finish()
				p.close()
				request.method = parser.methods[p.info.method]
				request.url = p.info.url
				try
					request.data = JSON.parse(p.line)
					request.body = request.data
				catch error
					request.data = {}
					request.body = {}

	return d

exports.multiReq = (req, res, next) ->
	req.batch = []
	if req.method is 'POST' and m = RE_BOUNDARY.exec(req.headers['content-type'])
		d = parseInto(req.batch, m)
		d.on 'finish', ->
			Promise.all(d.pending).then -> next()
		req.pipe(d)
	else next()
