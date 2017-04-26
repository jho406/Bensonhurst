#= require breezy/doubly_linked_list
#= require breezy/snapshot
#= require breezy/progress_bar
#= require breezy/parallel_queue
#= require breezy/component_url

PAGE_CACHE_SIZE = 20

class Breezy.Controller
  constructor: ->
    @atomCache = {}
    @history = new Breezy.Snapshot(this)
    @transitionCacheEnabled = false
    @requestCachingEnabled = true

    @progressBar = new Breezy.ProgressBar 'html'
    @pq = new Breezy.ParallelQueue
    @http = null

    @history.rememberCurrentUrlAndState()

  currentPage: =>
    @history.currentPage

  request: (url, options = {}) =>
    options = Breezy.Utils.reverseMerge options,
      pushState: true

    url = new Breezy.ComponentUrl url
    return if @pageChangePrevented(url.absolute, options.target)

    if url.crossOrigin()
      document.location.href = url.absolute
      return

    @history.cacheCurrentPage()
    if @progressBar? and !options.async
      @progressBar?.start()
    restorePoint = @history.transitionCacheFor(url.absolute)

    if @transitionCacheEnabled and restorePoint and restorePoint.transition_cache
      @history.reflectNewUrl(url)
      @restore(restorePoint)
      options.showProgressBar = false

    options.cacheRequest ?= @requestCachingEnabled
    options.showProgressBar ?= true

    Breezy.Utils.triggerEvent Breezy.EVENTS.FETCH, url: url.absolute, options.target

    if options.async
      options.showProgressBar = false
      req = @createRequest(url, options)
      req.onError = ->
        Breezy.Utils.triggerEvent Breezy.EVENTS.ERROR, null, options.target
      @pq.push(req)
      req.send(options.payload)
    else
      @pq.drain()
      @http?.abort()
      @http = @createRequest(url, options)
      @http.send(options.payload)

  enableTransitionCache: (enable = true) =>
    @transitionCacheEnabled = enable

  disableRequestCaching: (disable = true) =>
    @requestCachingEnabled = not disable
    disable

  restore: (cachedPage, options = {}) =>
    @http?.abort()
    @history.changePage(cachedPage, options)

    @progressBar?.done()
    Breezy.Utils.triggerEvent Breezy.EVENTS.RESTORE
    Breezy.Utils.triggerEvent Breezy.EVENTS.LOAD, cachedPage

  replace: (nextPage, options = {}) =>
    Breezy.Utils.withDefaults(nextPage, @history.currentBrowserState)
    @history.changePage(nextPage, options)
    Breezy.Utils.triggerEvent Breezy.EVENTS.LOAD, @currentPage()

  crossOriginRedirect: =>
    redirect = @http.getResponseHeader('Location')
    crossOrigin = (new Breezy.ComponentUrl(redirect)).crossOrigin()

    if redirect? and crossOrigin
      redirect

  pageChangePrevented: (url, target) =>
    !Breezy.Utils.triggerEvent Breezy.EVENTS.BEFORE_CHANGE, url: url, target

  cache: (key, value) =>
    return @atomCache[key] if value == null
    @atomCache[key] ||= value

  # Events
  onLoadEnd: => @http = null

  onLoad: (xhr, url, options) =>
    Breezy.Utils.triggerEvent Breezy.EVENTS.RECEIVE, url: url.absolute, options.target
    nextPage =  @processResponse(xhr)
    if xhr.status == 0
      return

    if nextPage
      if options.async && url.pathname != @currentPage().pathname

        unless options.ignoreSamePathConstraint
          @progressBar?.done()
          Breezy.Utils.warn("Async response path is different from current page path")
          return

      if options.pushState
        @history.reflectNewUrl url

      Breezy.Utils.withDefaults(nextPage, @history.currentBrowserState)

      if nextPage.action != 'graft'
        @history.changePage(nextPage, options)
        Breezy.Utils.triggerEvent Breezy.EVENTS.LOAD, @currentPage()
      else
        ##clean this up
        @history.graftByKeypath("data.#{nextPage.path}", nextPage.data)

      if options.showProgressBar
        @progressBar?.done()
      @history.constrainPageCacheTo()
    else
      if options.async
        Breezy.Utils.triggerEvent Breezy.EVENTS.ERROR, xhr, options.target
      else
        @progressBar?.done()
        document.location.href = @crossOriginRedirect() or url.absolute

  onProgress: (event) =>
    @progressBar.advanceFromEvent(event)

  onError: (url) =>
    document.location.href = url.absolute

  createRequest: (url, opts)=>
    jsAccept = 'text/javascript, application/x-javascript, application/javascript'
    requestMethod = opts.requestMethod || 'GET'

    xhr = new XMLHttpRequest
    xhr.open requestMethod, url.formatForXHR(cache: opts.cacheRequest), true
    xhr.setRequestHeader 'Accept', jsAccept
    xhr.setRequestHeader 'X-XHR-Referer', document.location.href
    xhr.setRequestHeader 'X-Silent', opts.silent if opts.silent
    xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'
    xhr.setRequestHeader 'Content-Type', opts.contentType if opts.contentType

    csrfToken = Breezy.CSRFToken.get().token
    xhr.setRequestHeader('X-CSRF-Token', csrfToken) if csrfToken

    if !opts.silent
      xhr.onload = =>
        self = ` this `
        redirectedUrl = self.getResponseHeader 'X-XHR-Redirected-To'
        actualUrl = redirectedUrl || url
        @onLoad(self, actualUrl, opts)
    else
      xhr.onload = =>
        @progressBar?.done()

    xhr.onprogress = @onProgress if @progressBar and opts.showProgressBar
    xhr.onloadend = @onLoadEnd
    xhr.onerror = =>
      @onError(url)
    xhr

  processResponse: (xhr) ->
    if @hasValidResponse(xhr)
      return @responseContent(xhr)

  hasValidResponse: (xhr) ->
    not @clientOrServerError(xhr) and @validContent(xhr) and not @downloadingFile(xhr)

  responseContent: (xhr) ->
    new Function("'use strict'; return " + xhr.responseText )()

  clientOrServerError: (xhr) ->
    400 <= xhr.status < 600

  validContent: (xhr) ->
    contentType = xhr.getResponseHeader('Content-Type')
    jsContent = /^(?:text\/javascript|application\/x-javascript|application\/javascript)(?:;|$)/

    contentType? and contentType.match jsContent

  downloadingFile: (xhr) ->
    (disposition = xhr.getResponseHeader('Content-Disposition'))? and
      disposition.match /^attachment/

