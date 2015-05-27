require './config.rb'

class App < Sinatra::Application
  # GET /?key=<api_key> - retrieve current state of the crawler
  get '/' do
    # Authorize the request
    error 401, JSON.pretty_generate(error: 'Unauthorized') and \
      return if ENV['API_KEY'] != params[:key]

    return JSON.pretty_generate(current_info)
  end

  # GET /start?key=<api_key> - start the crawler if idle
  get '/start' do
    # Authorize the request
    error 401, JSON.pretty_generate(error: 'Unauthorized') and \
      return if ENV['API_KEY'] != params[:key]

    start_job_if_idle

    return 'start'
  end

  # GET /kill?key=<api_key> - kill the working job
  get '/kill' do
    # Authorize the request
    error 401, JSON.pretty_generate(error: 'Unauthorized') and \
      return if ENV['API_KEY'] != params[:key]

    Sidekiq::Queue.new('default').clear
    Sidekiq::Queue.new('retry').clear
    Sidekiq::Queue.new('dead').clear
    App.work_ended(all: true)

    return 'kill'
  end

  # Report that a worker has done working, call this in each worker after
  # the work has done
  def self.work_ended(all: false)
    if all
      AppRedis.redis.set('crawler:working_workers', 0)
    else
      # decrease the working workers count
      AppRedis.redis.decr('crawler:working_workers')
    end

    # set the state to idle if all the works has been done
    if AppRedis.redis.get('crawler:working_workers').to_i < 1
      AppRedis.redis.set('crawler:state', 'idle')
      AppRedis.redis.set('crawler:finished_at', Time.now)
    end
  end

  # Sets the progress of the current work
  # It can be used like this in the worker: +App.work_2_progress = 0.8+
  100.times do |i|
    define_singleton_method("work_#{i}_progress=") do |progress|
      AppRedis.redis.set("crawler:worker_#{i}_progress", progress)
    end
  end

  private

  def start_job
    # Set the count of worker that should be started
    worker_count = 1

    # Start the worker here
    CrawlWorker.perform_async

    AppRedis.redis.set('crawler:state', 'working')
    AppRedis.redis.set('crawler:started_at', Time.now)
    AppRedis.redis.set('crawler:job_workers', worker_count)
    AppRedis.redis.set('crawler:working_workers', worker_count)

    # Reset the progress of each worker
    worker_count.times do |i|
      i -= 1
      AppRedis.redis.set("crawler:worker_#{i}_progress", 0)
    end
  end

  def start_job_if_idle
    return unless current_state == 'idle'
    start_job
  end

  def try_to_parse_date_from_redis(key)
    Time.parse(AppRedis.redis.get(key))
  rescue
    nil
  end

  def current_state
    AppRedis.redis.get('crawler:state') || 'idle'
  end

  def current_job_progress
    return nil if current_state == 'idle'
    job_workers = AppRedis.redis.get('crawler:job_workers').to_i
    return nil unless job_workers
    total_progress = 0.0

    job_workers.times do |i|
      i += 1
      total_progress += AppRedis.redis.get("crawler:worker_#{i}_progress").to_f
    end

    total_progress / job_workers.to_f
  end

  def current_job_started_at
    try_to_parse_date_from_redis('crawler:started_at')
  end

  def current_job_finished_at
    return nil if current_state != 'idle'
    try_to_parse_date_from_redis('crawler:finished_at')
  end

  def current_info
    info = { state: current_state }
    info[:job_progress] = current_job_progress if current_job_progress
    info[:job_started_at] = current_job_started_at if current_job_started_at
    info[:job_finished_at] = current_job_finished_at if current_job_finished_at

    info
  end
end
