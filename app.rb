require 'web_task_runner'

# Require the crawler
Dir[File.dirname(__FILE__) + '/crawler/*.rb'].each { |file| require file }

class CrawlWorker < WebTaskRunner::TaskWorker
  def exec
    crawler = NtustCourseCrawler.new(
      year: 2015,
      term: 1,
      update_progress: proc { |payload| WebTaskRunner.job_1_progress = payload[:progress] },
      after_each: proc do |payload|
        course = payload[:course]
        puts "Saving course #{course[:code]} ..."
        RestClient.put("#{ENV['DATA_MANAGEMENT_API_ENDPOINT']}/#{course[:code]}?key=#{ENV['DATA_MANAGEMENT_API_KEY']}",
          { ENV['DATA_NAME'] => course }
        )
        WebTaskRunner.job_1_progress = payload[:progress]
      end
    )

    courses = crawler.courses(details: true, max_detail_count: 10_000)

    # TODO: delete the courses which course code not present in th list
  end
end

WebTaskRunner.jobs << CrawlWorker
