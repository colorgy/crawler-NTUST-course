require 'active_record'
require_relative '../app.rb'
require_relative './ntust_course_crawler.rb'

class DataModel < ActiveRecord::Base
  self.table_name = ENV['DATABASE_TABLE_NAME']
  establish_connection ENV['DATABASE_URL']

  def self.cols
    @cols ||= DataModel.columns.map { |c| c.name.to_sym }
  end
end

class CrawlWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  @@crawler = NtustCourseCrawler.new(
    progress_proc: proc { |p| App.work_1_progress = p }
  )

  def perform
    courses = @@crawler.courses(details: true, max_detail_count: 10_000)

    DataModel.transaction do
      courses.each do |course|
        data = DataModel.first_or_create!(code: course[:code])
        data.assign_attributes(course.slice(*DataModel.cols))
        data.save!
      end
    end

    App.work_ended
  end
end
