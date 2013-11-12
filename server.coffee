
express = require 'express'
http = require('http')
path = require('path')
render = require('./render').render

app = express()

# all environments
app.set('port', process.env.PORT || 3001)
app.use(express.favicon())
app.use(express.logger('dev'))
app.use(express.static(path.join(__dirname, '_site')))

# development only
if 'development' == app.get('env')
  app.use express.errorHandler()

start_render_timer = ->
  setTimeout render, process.env.TIMER || 24 * 3600 * 1000

http.createServer(app).listen app.get('port'), ()->
  render()
  start_render_timer()
  console.log "Express server listening on port #{app.get('port')}"
