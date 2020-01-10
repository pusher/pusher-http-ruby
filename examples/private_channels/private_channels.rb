require 'sinatra'
require 'sinatra/cookies'
require 'sinatra/json'
require 'pusher'

# You can get these variables from http://dashboard.pusher.com
pusher = Pusher::Client.new(
  app_id: 'YOUR-APP-ID',
  key: 'YOUR-APP-KEY',
  secret: 'YOUR-APP-SECRET',
  cluster: 'CLUSTER'
)

set :public_folder, 'public'

get "/" do
  redirect '/private_channels.html'
end

# Emulate rails behaviour where this information would be stored in session
get '/signin' do
  cookies[:user_id] = 'example_cookie'
  'Ok'
end

# Auth endpoint: https://pusher.com/docs/channels/server_api/authenticating-users
post '/pusher/auth' do
  channel_data = {
      user_id: 'example_user',
      user_info: {
        name: 'example_name',
        email: 'example_email'
      }
    }

  if cookies[:user_id] == 'example_cookie'
    response = pusher.authenticate(params[:channel_name], params[:socket_id], channel_data)
    json response
  else
    status 403
  end
end

get '/pusher_trigger' do
  channels = ['private-channel-test'];

  begin
    pusher.trigger(channels, 'test-event', {
      message: 'hello world'
    })
  rescue Pusher::Error => e
  # (Pusher::AuthenticationError, Pusher::HTTPError, or Pusher::Error)
  end

  'Triggered!'
end
