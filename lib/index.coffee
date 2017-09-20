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
		body =
			headers: {}
			method: null
			url: null
			data: []
			_isChangeSet: false

		onEnd = (part) ->
			->
				dst[slot] = (part)

		part.on 'header', (header) ->
			Object.assign body.headers, header

		part.on 'data', (data) ->
			if m1 = RE_BOUNDARY.exec(body.headers['content-type']?[0])
				pend = new Promise (resolve, reject) ->
					d1 = parseInto(body.data, m1)
					finish = onEnd({ _isChangeSet: true, changeSet: body.data })
					d1.on 'finish', ->
						finish()
						resolve()
					bodyStream = new Readable()
					bodyStream.pipe(d1)
					bodyStream.push(data.toString())
					bodyStream.push(null)
				d.pending.push(pend)
			else
				part.on 'end', onEnd body
				p = new parser(parser.REQUEST)
				p.execute(data)
				p.finish()
				p.close()
				body.method = parser.methods[p.info.method]
				body.url = p.info.url
				try
					body.data = JSON.parse(p.line)
				catch error
					body.data = {}

	return d

exports.multiReq = (req, res, next) ->
	req.batch = []
	if req.method is 'POST' and m = RE_BOUNDARY.exec(req.headers['content-type'])
		d = parseInto(req.batch, m)
		d.on 'finish', ->
			Promise.all(d.pending).then -> next()
		req.pipe(d)
	else next()
