{ HTTPParser: parser } = require 'http-parser-js'
dicer = require 'dicer'
Readable = require 'readable-stream'
Promise = require 'bluebird'

RE_BOUNDARY = /^multipart\/.+?(?:;\s?boundary=(?:(?:"(.+)")|(?:([^\s]+))))$/i

parseInto = (dst, boundary, debug) ->
	d = new dicer { boundary: boundary[1] || boundary[2] }
	d.pending = []
	position = 0
	d.on 'part', (p) ->
		slot = position++
		b = { headers: {}, method: null, url: null, data: [], _isChangeSet: false }

		onEnd = (part) ->
			->
				dst[slot] = (part)

		p.on 'header', (header) ->
			Object.assign b.headers, header

		p.on 'data', (data) ->
			if m1 = RE_BOUNDARY.exec(data.toString().slice(14).split('\r\n')[0])
				pend = new Promise (resolve, reject) ->
					d1 = parseInto b.data, m1, 2
					finish = onEnd { _isChangeSet: true, changeSet: b.data }
					d1.on 'finish', ->
						finish()
						resolve()
					bodyStream = new Readable()
					bodyStream.pipe d1
					bodyStream.push data.toString()
					bodyStream.push null
				d.pending.push(pend)
			else
				p.on 'end', onEnd b
				p = new parser parser.REQUEST
				p.execute data
				p.finish()
				p.close()
				b.method = parser.methods[p.info.method]
				b.url = p.info.url
				try
					b.data = JSON.parse p.line
				catch error
					b.data = {}

	return d


exports.multiReq = (req, res, next) ->
	req.batch = []
	if req.method == 'POST' and req.headers['content-type'] and (m = RE_BOUNDARY.exec(req.headers['content-type']))
		d = parseInto req.batch, m, 1
		d.on 'finish', ->
			Promise.all(d.pending)
			.then -> next()

		req.pipe d
	else next()
