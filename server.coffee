bodyParser         = require 'body-parser'
cookieParser       = require 'cookie-parser'
express            = require 'express'
MeshbluConfig      = require 'meshblu-config'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
MeshbluHttp        = require 'meshblu-http'
morgan             = require 'morgan'
OctobluRaven       = require 'octoblu-raven'
packageVersion     = require 'express-package-version'
passport           = require 'passport'
session            = require 'cookie-session'

Router = require './app/routes'
Config = require './app/config'
debug = require('debug')('meshblu-github-authenticator:server')

port = process.env.MESHBLU_GITHUB_AUTHENTICATOR_PORT ? process.env.PORT ? 80

ravenExpress = new OctobluRaven().express()

app = express()
app.use ravenExpress.requestHandler()
app.use ravenExpress.errorHandler()

app.use meshbluHealthcheck()
app.use packageVersion()
app.use morgan 'dev', immediate: false unless @disableLogging

app.use bodyParser.json()
app.use bodyParser.urlencoded(extended: true)
app.use cookieParser()

app.use session
  secret: 'super awesome cool secret'
  resave: false
  saveUninitialized: true

app.use passport.initialize()
app.use passport.session()

passport.serializeUser (user, done) =>
  done null, user.id

passport.deserializeUser (user, done) =>
  done null, user

app.engine 'html', require('ejs').renderFile

app.set 'view engine', 'html'

app.set 'views', __dirname + '/app/views'

meshbluJSON = new MeshbluConfig().toJSON()
meshbluJSON.name = process.env.MESHBLU_GITHUB_AUTHENTICATOR_NAME ? 'Github Authenticator'

meshbluHttp = new MeshbluHttp meshbluJSON

meshbluHttp.device meshbluJSON.uuid, (error, device) ->
  if error?
    console.error error.message, error.stack
    process.exit 1

  meshbluHttp.setPrivateKey(device.privateKey) unless meshbluHttp.privateKey

config = new Config {meshbluHttp, meshbluJSON}
config.register()

router = new Router app
router.register()

app.listen port, =>
  debug "Meshblu Github Authenticator..."
  debug "Listening at localhost:#{port}"

process.on 'SIGTERM', =>
  console.log 'SIGTERM caught, exiting'
  process.exit 0
