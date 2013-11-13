
request = require 'request'
async = require 'async'

client_id = process.env.GITHUB_CLIENT_ID
client_secret = process.env.GITHUB_CLIENT_SECRET

repo_depon = {}   # map from full_name to which repos depends on it
repos = {}        # map from full_name to repo info
request_timeout = 600000

parse_deps = (data) ->
  regex = /(git|https):\/\/(www\.|)github\.com\/(.*)\.git/g
  result = []
  for line in data.split('\n')
    line = line.split('%')[0]
    while (res = regex.exec(line)?[3])
      result.push res
  return result

parse_repo = (repo, cb) ->
  repos[repo.full_name] = repo
  dep_url = "https://raw.github.com/#{repo.full_name}/#{repo.default_branch}/rebar.config"
  request {url: dep_url, json: false, timeout: request_timeout}, (e, r, data) ->
    if r?.statusCode == 404
      console.log "Parsed repo #{repo.full_name}, no rebar.config found."
      return cb()

    if e or r.statusCode != 200
      console.log "Parsed repo #{repo.full_name} error"
      console.log {err: e, res: r?.statusCode}
      return cb()

    deps = parse_deps(data)
    for d_name in deps
      repo_depon[d_name] = [] if not repo_depon[d_name]
      repo_depon[d_name].push repo.full_name
    console.log "Parsed repo #{repo.full_name}, has #{deps.length} dependencies."
    cb()

get_timeout = (reset) ->
  timeout =  new Date(reset * 1000) - new Date()
  return 0 if timeout < 0
  return timeout

fetch_page = (page, cb) ->
    repo_url = "https://api.github.com/search/repositories?q=language:erlang&sort=stars&per_page=100&page=#{page}&client_id=#{client_id}&client_secret=#{client_secret}"
    request {url: repo_url, json: true, timeout: request_timeout}, (e, r, data) ->

      if r?.headers['x-ratelimit-remaining'] == '0' and data?.message?.match('API rate limit exceeded')
        timeout = get_timeout Number(r.headers['x-ratelimit-reset'])
        console.log "Search rate limit exceeded, fetch after #{timeout}ms"
        setTimeout (()->fetch_page(page, cb)), timeout
        return

      if e or r.statusCode != 200
        console.log "Fetch page #{page} error"
        console.log {err: e, res: r?.statusCode}
        return cb()

      async.each data.items, parse_repo, (err) ->
        cb()

fetch_repos = (full_name, cb) ->
    return cb() if repos[full_name]
    repo_url = "https://api.github.com/repos/#{full_name}?client_id=#{client_id}&client_secret=#{client_secret}"
    request {url: repo_url, json:true, timeout: request_timeout}, (e, r, repo) ->

      if r?.headers['x-ratelimit-remaining'] == '0' and repo?.message?.match('API rate limit exceeded')
        timeout = get_timeout Number(r.headers['x-ratelimit-reset'])
        console.log "Core rate limit exceeded, fetch after #{timeout}ms"
        setTimeout (()->fetch_repos(full_name, cb)), timeout
        return

      if e or r.statusCode != 200
        console.log "Fetch repo #{full_name} error"
        console.log {err: e, res: r?.statusCode}
        return cb()

      console.log "Fetched info of repo #{full_name}"
      repos[repo.full_name] = repo
      cb()

exports.fetch = (cb) ->
  # github only allow search 1000 repos, 10 pages of 100 repos per page
  async.each [1...11], fetch_page, (err) ->
    return console.log err if err
    async.each Object.keys(repo_depon), fetch_repos, (err) ->
      return console.log err if err
      res = ({name: name, depon: depon, info: repos[name]} for name, depon of repo_depon)
      res.sort (a, b) -> b.depon.length - a.depon.length
      cb(res)
