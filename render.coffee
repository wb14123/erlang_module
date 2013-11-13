
jade = require 'jade'
fetch = require('./fetch').fetch
fs = require 'fs'
per_page = 10

exports.render = ->
  fetch (repos) ->
    fs.writeFileSync('repos.json', JSON.stringify(repos))

    pages = Math.ceil(repos.length / per_page)
    for i in [0...pages]
      start = i * per_page
      end = (i + 1) * per_page

      start_page = end_page = undefined
      if (i + 1) <= 7
        start_page = 1
        end_page =  15
      else if (i + 1) >= pages - 7
        start_page = pages - 14
        end_page = pages
      else
        start_page = (i+1) - 7
        end_page = (i+1) + 7

      jade.renderFile './index.jade', {
          update: new Date().toUTCString(),
          repos: repos[start...end],
          pages: [start_page...end_page + 1],
          cur_page: (i+1),
          per_page: per_page},
        (err, html) ->
          return console.log err if err
          return fs.writeFileSync('_site/index.html', html) if i == 0
          fs.writeFileSync("_site/#{i+1}.html", html)
