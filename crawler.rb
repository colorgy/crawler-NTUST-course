require 'rest_client'
require 'nokogiri'
require 'json'
require 'iconv'
require 'uri'
require 'ruby-progressbar'
# 難得寫註解，總該碎碎念。

class Crawler
  attr_reader :semester_list, :courses_list, :query_url, :result_url

  def initialize
    @query_url = "http://140.118.31.215/querycourse/ChCourseQuery/QueryCondition.aspx"
    @result_url = "http://140.118.31.215/querycourse/ChCourseQuery/QueryResult.aspx"
  end

  def prepare_post_data
    r = RestClient.get @query_url
    query_page = Nokogiri::HTML(r.to_s)

    # 撈第一次資料，拿到 hidden 的表單驗證。
    @view_state = query_page.css('input[name="__VIEWSTATE"]').first['value']
    @view_state_generator = query_page.css('input[name="__VIEWSTATEGENERATOR"]').first['value']
    @event_validation = query_page.css('input[name="__EVENTVALIDATION"]').first['value']
    @semester_list = query_page.css('#semester_list option').map {|option| option['value']}
    @cookies = r.cookies
    nil
  end

  def get_courses(sem = 0)
    # 初始 courses 陣列
    @courses = []

    # 把表單驗證，還有要送出的資料弄成一包 hash
    post_data = {
      :__VIEWSTATE => @view_state,
      :__VIEWSTATEGENERATOR => @view_state_generator,
      :__EVENTVALIDATION => @event_validation,
      :Acb0101 => 'on',
      :BCH0101 => 'on',
      # 看是第幾學年度，預設用最新的
      :semester_list => @semester_list[sem],
      :QuerySend => '送出查詢'
    }

    # 先 post 一下，讓 server 知道你送出查詢(以及一些用不到 Google 來的 exception handling)
    r = RestClient.post( @query_url, post_data , :cookies => @cookies){ |response, request, result, &block|
      if [301, 302, 307].include? response.code
        response.follow_redirection(request, result, &block)
      else
        # final_url = request.url
        response.return!(request, result, &block)
      end
    }
    # 然後再到結果頁看結果，記得 cookie，因為有 session id。
    puts "loading Courses List..."
    r = RestClient.get( @result_url, :cookies => @cookies )

    @courses_list = Nokogiri::HTML(r.to_s)

    progressbar = ProgressBar.create(:total => @courses_list.css('table').last.css('tr')[1..-1].length)
    # 跳過第一列，因為是 table header，何不用 th = =?
    @courses_list.css('table').last.css('tr')[1..-1].each_with_index do |row, index|
      progressbar.increment
      # 稍微 log 下到哪了
      # print "#{index}, "


      # 每一欄
      table_data = row.css('td')

      # 分配欄位，多麼機械化！
      course_code = table_data[0].text
      course_title = table_data[1].text
        # 跳過 '空白列'，覺得 buggy
        next if table_data[2].css('a').empty?
      detail_url = table_data[2].css('a').first['href']
      credits = table_data[3].text
      required_or_elective = table_data[4].text
      full_or_half_semester = table_data[5].text
      lecturer = table_data[6].text
      course_time_location = table_data[7].text.split(' ')
      people_in_course = table_data[10].text
      notes = table_data[11].text

      # 好，讓我們爬更深一層
      r = RestClient.get(URI.encode(detail_url))
      # 做一個編碼轉換的動作，防止 Nokogiri 解析失敗的動作
      ic = Iconv.new("utf-8//translit//IGNORE","utf-8")
      detail_page = Nokogiri::HTML(ic.iconv(r.to_s))

      # 總共上下兩張大 table
      table_head = detail_page.css('.tblMain').first
      # table_detail = detail_page.css('.tblMain').last

      # 解析時間教室字串！一般來說長這樣：M6(IB-509) M7(IB-509)
      course_time_location = {}
      table_head.css('#lbl_timenode').text.split(' ').each do |raw_timenode|
        course_time_location.merge! ({
          # {"M6" => IB-509} 的概念
          "#{raw_timenode[0..1]}" => raw_timenode[2..-1].gsub(/[\(\)]/, '')
        })
      end

      # 學年 / 課程宗旨 / 課程大綱 / 教科書 / 參考書目 / 修課學生須知 / 評量方式 / 備註說明
      semester = detail_page.css('#lbl_semester').text
      course_objective = detail_page.css('#tbx_object').text
      course_outline = detail_page.css('#tbx_content').text
      textbook = detail_page.css('#tbx_textbook').text
      references = detail_page.css('#tbx_refbook').text
      notice = detail_page.css('#tbx_note').text
      grading = detail_page.css('#tbx_grading').text
      det_note = detail_page.css('#tbx_remark').text

      # 英語課程名稱 / 先修課程 / 課程相關網址
      english_course_title = detail_page.css('#lbl_engname').text
      prerequisites = detail_page.css('#lbl_precourse').text
      course_website = detail_page.css('#hlk_coursehttp').text

      # hash 化 course
      @courses << {
        :title => course_title,
        :code => course_code,
        :lecturer => lecturer,
        :credits => credits,
        :required => (required_or_elective == '選'),
        :full_or_half_semester => full_or_half_semester,
        :semester => semester,
        :people_in_course => people_in_course,
        :time_location => course_time_location,
        :english_title => english_course_title,
        :prerequisites => prerequisites,
        :website => course_website,
        :objective => course_objective,
        :outline => course_outline,
        :textbook => textbook,
        :references => references,
        :notice => notice,
        :grading => grading,
        :note => det_note,
        :about => notes,
        :url => URI.encode(detail_url)
      }
    end

    nil

  end

  # 存檔
  def save_to(filename='courses.json')
    File.open(filename, 'w') {|f| f.write(JSON.pretty_generate(@courses))}
  end


end

crawler = Crawler.new
crawler.prepare_post_data
crawler.get_courses
crawler.save_to
