express       = require 'express'
app           = module.exports = express()
flash         = require 'connect-flash'
assets        = require 'connect-assets'
mongoose      = require 'mongoose'
path          = require 'path'
{requireDir}  = require './lib/require_dir'

ROOT_DIR = "#{__dirname}/.."

app.configure ->
  app.set 'version', require("#{ROOT_DIR}/coffee-box.config.json").version
  app.set k, v for k, v of require("#{ROOT_DIR}/coffee-box.config.json")
  app.set 'utils', requireDir("#{ROOT_DIR}/coffee-box/lib")
  app.set 'helpers', requireDir("#{ROOT_DIR}/coffee-box/helpers")
  app.set 'models', requireDir("#{ROOT_DIR}/coffee-box/models")
  app.settings.models.Config.Load (err,config)->
    if err
      console.error err
      return process.exit 1
    config.Apply app
    
    
  app.locals.coffeeBox =
    version: app.settings.version
    nodejsVersion: process.version

  app.set 'controllersGetter', requireDir("#{ROOT_DIR}/coffee-box/controllers")
  app.set 'view engine', 'jade'
  app.set 'views',"#{ROOT_DIR}"
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser()
  app.use express.session(secret: app.settings.secretKey)
  app.use flash()
  
  app.set 'themeAssetsContext',{}
  app.set 'defaultAssetsContext',{}
  app.use assets
    src                     : path.join ROOT_DIR,'themes','default','assets'
    build                   : true
    detectChanges           : false
    buildDir                : false
    helperContext           : app.get 'defaultAssetsContext'
  app.use express.static path.join ROOT_DIR,'themes','public'

  app.use (req,res,next)-> app.get('assetsRoute') req,res,next
  app.use (req,res,next)-> app.get('publicRoute') req,res,next

  # make some 2.x-style compatible helpers
  app.locals[k]=v for k,v of app.settings.helpers
  app.use (req,res,next)->
    res.locals.messages = require('express-messages')(req,res)
    res.locals.session = req.session
    next()


  # Since express does not intend to implement multiple view path, we'll have to hack it
  # https://github.com/visionmedia/express/pull/1186
  app.use (req,res,next)->
    res.expressRender = res.render
    res.render  = (view,data)->
      viewPath = path.join(ROOT_DIR,'themes',app.locals.config.theme,'views',view+'.jade')
      path.exists viewPath,(exists)->
        if exists
          res.locals.assets = app.get 'themeAssetsContext'
          res.expressRender viewPath,data
        else
          res.locals.assets = app.get 'defaultAssetsContext'
          res.expressRender path.join(ROOT_DIR,'themes','default','views',view),data
    next()


  app.use app.router
  app.use require './lib/exceptions'

app.configure 'development', ->
  app.use express.logger('dev')
  app.use express.errorHandler(dumpException: true, showStack: true)

app.configure 'production', ->
  app.use express.logger()
  app.use express.errorHandler()

mongoose.connect app.settings.dbpath, (err) ->
  if err
    console.error err
    return process.exit()
require('./routes') app
