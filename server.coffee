
express = require 'express'
http = require('http')
path = require('path')
render = require('./render').render

host = process.env.ERLANG_MODULES_HOST || 'erlang-modules.binwang.me'

app = express()

# all environments
app.set('port', process.env.PORT || 3001)
app.use(express.favicon())
app.use(express.logger('dev'))

app.use (req, res, next) ->
  return next() if req.headers.host == host
  res.redirect("http://#{host}")

app.use(express.static(path.join(__dirname, '_site')))

# development only
if 'development' == app.get('env')
  app.use express.errorHandler()

start_render_timer = ->
  setTimeout render, process.env.TIMER || 24 * 3600 * 1000

http.createServer(app).listen app.get('port'), ()->
  setTimeout render, 1000
  start_render_timer()
  console.log "Express server listening on port #{app.get('port')}"
