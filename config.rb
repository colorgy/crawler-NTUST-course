# Turn off stdout buffering that interferes stdout logging
$stdout.sync = true

require 'bundler'
Bundler.require

# Load environment variables from .env
Dotenv.load

# Require the crawler
Dir[File.dirname(__FILE__) + '/crawler/*.rb'].each { |file| require file }

# Create Redis connection module
class WebTaskRunner < Sinatra::Application
  module RedisModule
    def self.connection
      proc { Redis.new(url: ENV['REDIS_URL']) }
    end

    def self.redis
      @redis ||= connection.call
    end
  end
end

# Set Redis connections for both Sidekiq server and client
Sidekiq.configure_server do |config|
  config.redis = ConnectionPool.new(&WebTaskRunner::RedisModule.connection)
end

Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(&WebTaskRunner::RedisModule.connection)
end
