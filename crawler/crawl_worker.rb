require 'rest-client'
require_relative '../app.rb'
require_relative './ntust_course_crawler.rb'

class CrawlWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  @@crawler = NtustCourseCrawler.new(
    update_progress: proc { |payload| WebTaskRunner.work_1_progress = payload[:progress] },
    after_each: proc do |payload|
      course = payload[:course]
      puts "Saving course #{course[:code]} ..."
      RestClient.put("#{ENV['DATA_MANAGEMENT_API_ENDPOINT']}/#{course[:code]}?key=#{ENV['DATA_MANAGEMENT_API_KEY']}",
        { ENV['DATA_NAME'] => course }
      )
      WebTaskRunner.work_1_progress = payload[:progress]
    end
  )

  def perform
    return if WebTaskRunner.current_state == 'idle'
    courses = @@crawler.courses(details: true, max_detail_count: 10_000)

    puts "Work ##{1} done."
    WebTaskRunner.work_ended
  end
end
