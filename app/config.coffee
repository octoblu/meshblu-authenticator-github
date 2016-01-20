passport = require 'passport'
GithubStrategy = require('passport-github').Strategy
{DeviceAuthenticator} = require 'meshblu-authenticator-core'
debug = require('debug')('meshblu-github-authenticator:config')

githubOauthConfig =
  clientID: process.env.GITHUB_CLIENT_ID
  clientSecret: process.env.GITHUB_CLIENT_SECRET
  callbackURL: process.env.GITHUB_CALLBACK_URL
  passReqToCallback: true

class GithubConfig
  constructor: (@meshbluHttp, @meshbluJSON) ->

  onAuthentication: (request, accessToken, refreshToken, profile, done) =>
    profileId = profile?.id
    fakeSecret = 'github-authenticator'
    authenticatorUuid = @meshbluJSON.uuid
    authenticatorName = @meshbluJSON.name

    deviceModel = new DeviceAuthenticator {authenticatorUuid, authenticatorName, @meshbluHttp}
    query = {}
    query[authenticatorUuid + '.id'] = profileId
    device =
      name: profile.name
      type: 'octoblu:user'

    getDeviceToken = (uuid) =>
      @meshbludb.generateAndStoreToken uuid, (error, device) =>
        device.id = profileId
        done null, device

    deviceCreateCallback = (error, createdDevice) =>
      return done error if error?
      getDeviceToken createdDevice?.uuid

    deviceFindCallback = (error, foundDevice) =>
      # return done error if error?
      return getDeviceToken foundDevice.uuid if foundDevice?
      deviceModel.create
        query: query
        data: device
        user_id: profileId
        secret: fakeSecret
      , deviceCreateCallback

    deviceModel.findVerified query: query, password: fakeSecret, deviceFindCallback

  register: =>
    passport.use new GithubStrategy githubOauthConfig, @onAuthentication

module.exports = GithubConfig
