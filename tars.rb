require 'slack-rtmapi'
require 'uri'
require 'pg'

@db = if ENV['DATABASE_URL']
  uri = URI.parse(ENV['DATABASE_URL'])
  PG::Connection.open(
    host: uri.host,
    user: uri.user,
    password: uri.password,
    port: uri.port,
    dbname: uri.path[1..-1]
  )
else
  PG::Connection.open dbname: 'tars'
end

@db.exec 'CREATE TABLE IF NOT EXISTS urls (url TEXT)'

def add_url(url)
  @db.exec 'INSERT INTO urls (url) VALUES ($1)', [url]
end

def url_exists?(url)
  @db.exec('SELECT COUNT(*) FROM urls WHERE url = $1', [url]).values.flatten.first.to_i != 0
end

url = SlackRTM.get_url token: ENV['SLACK_TOKEN']
client = SlackRTM::Client.new websocket_url: url
channel_id = ENV['CHANNEL_ID']

client.on(:message) do |data|
  p data
  if data['type'] == 'message' && data['channel'] == channel_id
    urls = data['text'].to_s.scan(%r{https?://[^\s]+})

    if urls.any? { |url| url_exists? url }
      client.send({channel: channel_id, text: 'Repost!', type: 'message'})
    end

    urls.each do |url|
      add_url(url)
    end
  end
end

client.main_loop
