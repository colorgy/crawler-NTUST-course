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

    start_task_if_idle

    return 'start'
  end

  # GET /kill?key=<api_key> - kill the working job
  get '/kill' do
    # Authorize the request
    error 401, JSON.pretty_generate(error: 'Unauthorized') and \
      return if ENV['API_KEY'] != params[:key]

    kill_task

    return 'kill'
  end

  # Report that a worker has done working, call this in each worker after
  # the work has done
  def self.work_ended(all: false)
    if all
      AppRedis.redis.set('task:working_workers', 0)
    else
      # decrease the working workers count
      AppRedis.redis.decr('task:working_workers')
    end

    # set the state to idle if all the works has been done
    if AppRedis.redis.get('task:working_workers').to_i < 1
      AppRedis.redis.set('task:state', 'idle')
      AppRedis.redis.set('task:finished_at', Time.now)
    end
  end

  # Sets the progress of the current work
  # It can be used like this in the worker: +App.work_2_progress = 0.8+
  100.times do |i|
    define_singleton_method("work_#{i}_progress=") do |progress|
      AppRedis.redis.set("task:worker_#{i}_progress", progress)
    end
  end

  def self.start_task
    kill_task
    AppRedis.redis.set('task:state', 'working')
    AppRedis.redis.set('task:started_at', Time.now)

    # Set the count of worker that should be started
    worker_count = 1

    # Start the worker here
    CrawlWorker.perform_async

    AppRedis.redis.set('task:task_workers', worker_count)
    AppRedis.redis.set('task:working_workers', worker_count)

    # Reset the progress of each worker
    worker_count.times do |i|
      i -= 1
      AppRedis.redis.set("task:worker_#{i}_progress", 0)
    end
  end

  def start_task
    App.start_task
  end

  def self.start_task_if_idle
    return unless current_state == 'idle'
    start_task
  end

  def start_task_if_idle
    App.start_task_if_idle
  end

  def self.kill_task
    ps = Sidekiq::ProcessSet.new
    ps.each do |p|
      p.stop! if p['busy'] > 0
    end
    sleep(0.5)
    Sidekiq::Queue.new.clear
    Sidekiq::ScheduledSet.new.clear
    Sidekiq::RetrySet.new.clear
    App.work_ended(all: true)
  end

  def kill_task
    App.kill_task
  end

  def self.try_to_parse_date_from_redis(key)
    Time.parse(AppRedis.redis.get(key))
  rescue
    nil
  end

  def try_to_parse_date_from_redis(key)
    App.try_to_parse_date_from_redis(key)
  end

  def self.current_state
    AppRedis.redis.get('task:state') || 'idle'
  end

  def current_state
    App.current_state
  end

  def self.current_task_progress
    return nil if current_state == 'idle'
    task_workers = AppRedis.redis.get('task:task_workers').to_i
    return nil unless task_workers
    total_progress = 0.0

    task_workers.times do |i|
      i += 1
      total_progress += AppRedis.redis.get("task:worker_#{i}_progress").to_f
    end

    total_progress / task_workers.to_f
  end

  def current_task_progress
    App.current_task_progress
  end

  def self.current_task_started_at
    try_to_parse_date_from_redis('task:started_at')
  end

  def current_task_started_at
    App.current_task_started_at
  end

  def self.current_task_finished_at
    return nil if current_state != 'idle'
    try_to_parse_date_from_redis('task:finished_at')
  end

  def current_task_finished_at
    App.current_task_finished_at
  end

  def self.current_info
    info = { state: current_state }
    info[:task_progress] = current_task_progress if current_task_progress
    info[:task_started_at] = current_task_started_at if current_task_started_at
    info[:task_finished_at] = current_task_finished_at if current_task_finished_at

    info
  end

  def current_info
    App.current_info
  end
end
