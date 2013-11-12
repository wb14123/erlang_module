
jade = require 'jade'
fetch = require('./fetch').fetch
fs = require 'fs'
per_page = 10

fetch (repos) ->
  pages = Math.ceil(repos.length / per_page)
  fs.writeFileSync('repos.json', JSON.stringify(repos))
  for i in [0...pages]
    start = i * per_page
    end = (i + 1) * per_page
    jade.renderFile './index.jade', {repos: repos[start...end], pages: [1...pages+1], cur_page: (i+1), per_page: per_page}, (err, html) ->
      return console.log err if err
      fs.writeFileSync('index.html', html) if i == 0
      fs.writeFileSync("#{i+1}.html", html)
