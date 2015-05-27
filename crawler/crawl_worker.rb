require_relative '../app.rb'
require_relative './ntust_course_crawler.rb'

class CrawlWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  @@crawler = NtustCourseCrawler.new

  def perform
    100.times do |i|
      sleep 0.2
      App.work_1_progress = i / 100.0
    end

    App.work_ended
  end
end

class CrawlWorker2
  include Sidekiq::Worker

  def perform
    50.times do |i|
      sleep 0.2
      App.work_2_progress = i / 50.0
    end

    # simulate errors
    raise if [false, false, true].sample

    App.work_ended
  end
end

class CrawlWorker3
  include Sidekiq::Worker

  def perform
    5.times do |i|
      sleep 1
      App.work_3_progress = i / 5.0
    end

    # simulate errors
    raise if [false, false, true].sample

    App.work_ended
  end
end
