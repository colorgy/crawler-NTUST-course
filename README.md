台科大課程資料爬蟲
==================

## 說明

針對 ASP.NET 老網站的範例，沒有 error handling，沒有 cache，需要再改寫。

完成度 60%。

## 使用

### `Crawler`

```ruby
require './crawler.rb'
crawler = Crawler.new(year: 2012, term: 2)
crawler.courses(details: false)  # => [{:name=>"控制系統分析與設計", :code=>"AC5009701", :year=>2012, :term=>2, :instructor=>"楊振雄", :credits=>3, :required=>true, :full_semester=>false, :students_enrolled=>8, :url=>"http://info.ntust.edu.tw/faith/edua/app/qry_linkoutline.aspx?semester=1012&courseno=AC5009701"}, {:name=>"數位控制", :code=>"AC5506701", :year=>2012, :term=>2, :instructor=>"楊振雄", :credits=>3, :required=>true, :full_semester=>false, :students_enrolled=>38, :url=>"http://info.ntust.edu.tw/faith/edua/app/qry_linkoutline.aspx?semester=1012&courseno=AC5506701"}, {:name=>"微機電製程分析及控制", :code=>"AC5515701", :year=>2012, :term=>2, :instructor=>"李敏凡", :credits=>3, :required=>true, :full_semester=>false, :students_enrolled=>6, :url=>"http://info.ntust.edu.tw/faith/edua/app/qry_linkoutline.aspx?semester=1012&courseno=AC5515701"}]
```
