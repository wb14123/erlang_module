
require 'coffee-script/register'

request = require 'request'
async = require 'async'

client_id = process.env.GITHUB_CLIENT_ID
client_secret = process.env.GITHUB_CLIENT_SECRET
header = {'User-Agent': 'Erlang-Modules'}

repo_depon = {}   # map from full_name to which repos depends on it
repos = {}        # map from full_name to repo info
request_timeout = 600000

erlang_mk_deps = {}

parse_erlang_mk_csv = (data) ->
  for line in data.split('\n')
    words = line.split('\t')
    name = words[0]
    gitUrl = words[2]
    regex = /(git|https):\/\/(www\.|)github\.com\/(\w+\/\w+)(\.git|)/g
    if (res = regex.exec(gitUrl)?[3])
      erlang_mk_deps[name] = res

parse_erlang_mk_deps = (data) ->
  depNames = []
  depRepos = {}
  depsRegex = /^DEPS\s*=\s*/g
  lines = data.split('\n')
  # find dep names
  for line in lines
    if line.match(depsRegex)
      names = line.replace(depsRegex, "")
      depNames = names.match(/\S+/g)
      break
  return [] unless (depNames? && depNames.length > 0)
  # find dep repos
  for line in lines
    for name in depNames
      regex = new RegExp("dep_#{name}\\s*=(.*)(git|https):\\/\\/(www\\.|)github\\.com\\/(\\w+\\/\\w+)(\\.git|)")
      if (res = line.match(regex)?[4])
        depRepos[name] = res
  # from name to repo
  result = []
  for name in depNames
    repoName = erlang_mk_deps[name] || depRepos[name]
    result.push repoName
  return result

fetch_erlang_mk_csv = (cb) ->
  erlang_mk_url = "https://raw.githubusercontent.com/ninenines/erlang.mk/master/packages.v2.tsv"
  request {url: erlang_mk_url, json: false, headers: header, timeout: request_timeout}, (e, r, data) ->
    if e or r.statusCode != 200
      console.log "Get erlang.mk index page error"
      console.log {err: e, res: r?.statusCode}
      return
    parse_erlang_mk_csv(data)
    cb()

parse_deps = (data) ->
  regex = /(git|https):\/\/(www\.|)github\.com\/(\w+\/\w+)(\.git|)/g
  result = []
  for line in data.split('\n')
    line = line.split('%')[0]
    while (res = regex.exec(line)?[3])
      result.push res
  return result

parse_repo_erlang_mk = (repo, cb) ->
  erlang_mk_url = "https://raw.github.com/#{repo.full_name}/#{repo.default_branch}/erlang.mk"
  makefile_url = "https://raw.github.com/#{repo.full_name}/#{repo.default_branch}/Makefile"
  request {url: erlang_mk_url, json: false, headers: header, timeout: request_timeout}, (e, r, data) ->
    if r?.statusCode == 404
      console.log "Parsed repo #{repo.full_name}, no erlang.mk found."
      return cb()

    request {url: makefile_url, json: false, headers: header, timeout: request_timeout}, (e, r, data) ->
      if r?.statusCode == 404
        console.log "Parsed repo #{repo.full_name}, no Makefile found."
        return cb()

      if e or r.statusCode != 200
        console.log "Parsed repo #{repo.full_name} error"
        console.log {err: e, res: r?.statusCode}
        return cb()

      do_deps repo, parse_erlang_mk_deps(data), cb

parse_repo = (repo, cb) ->
  repos[repo.full_name] = repo
  dep_url = "https://raw.github.com/#{repo.full_name}/#{repo.default_branch}/rebar.config"
  request {url: dep_url, json: false, headers: header, timeout: request_timeout}, (e, r, data) ->
    if r?.statusCode == 404
      console.log "Parsed repo #{repo.full_name}, no rebar.config found."
      return cb()

    if e or r.statusCode != 200
      console.log "Parsed repo #{repo.full_name} error"
      console.log {err: e, res: r?.statusCode}
      return cb()

    do_deps repo, parse_deps(data), cb

do_deps = (repo, deps, cb) ->
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
    request {url: repo_url, json: true, headers: header, timeout: request_timeout}, (e, r, data) ->

      if r?.headers['x-ratelimit-remaining'] == '0' and data?.message?.match('API rate limit exceeded')
        timeout = get_timeout Number(r.headers['x-ratelimit-reset'])
        console.log "Search rate limit exceeded, fetch after #{timeout}ms"
        setTimeout (()->fetch_page(page, cb)), timeout
        return

      if e or r.statusCode != 200
        console.log "Fetch page #{page} error"
        console.log {err: e, res: r?.statusCode}
        return cb()

      async.each data.items, parse_repo_erlang_mk, (err) ->
        async.each data.items, parse_repo, (err) ->
          cb()

fetch_repos = (full_name, cb) ->
    return cb() if repos[full_name]
    repo_url = "https://api.github.com/repos/#{full_name}?client_id=#{client_id}&client_secret=#{client_secret}"
    request {url: repo_url, json:true, headers: header, timeout: request_timeout}, (e, r, repo) ->

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
  # get erlang.mk index first
  fetch_erlang_mk_csv ->
    # github only allow search 1000 repos, 10 pages of 100 repos per page
    async.each [1...11], fetch_page, (err) ->
      return console.log err if err
      async.each Object.keys(repo_depon), fetch_repos, (err) ->
        return console.log err if err
        res = ({name: name, depon: depon, info: repos[name]} for name, depon of repo_depon)
        res.sort (a, b) -> b.depon.length - a.depon.length
        cb(res)
