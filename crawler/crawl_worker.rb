require 'rest-client'
require_relative '../app.rb'
require_relative './ntust_course_crawler.rb'

class CrawlWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  @@crawler = NtustCourseCrawler.new(
    progress_proc: proc { |p| App.work_1_progress = p }
  )

  def perform
    return if App.current_state == 'idle'
    courses = @@crawler.courses(details: true, max_detail_count: 10_000)

    courses.each_with_index do |course, index|
      puts "Saving course #{course[:code]} (#{index + 1}/#{courses.count})..."
      RestClient.put("#{ENV['DATA_MANAGEMENT_API_ENDPOINT']}/#{course[:code]}?key=#{ENV['DATA_MANAGEMENT_API_KEY']}",
        { ENV['DATA_NAME'] => course }
      )

    end

    puts "Work ##{1} done."
    App.work_ended
  end
end
