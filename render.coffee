
jade = require 'jade'
fetch = require('./fetch').fetch
fs = require 'fs'

fetch (repos) ->
  fs.writeFileSync('repos.json', JSON.stringify(repos))
  jade.renderFile './index.jade', {repos: repos}, (err, html) ->
    return console.log err if err
    fs.writeFileSync('index.html', html)
