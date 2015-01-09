require 'nokogiri'
require 'capybara'
require 'json'
require 'rest_client'
require 'ruby-progressbar'
require 'iconv'
require 'pry'

require_relative 'book.rb'

class Spider
  include Capybara::DSL

  def initialize
    Capybara.default_driver = :selenium 
  end

  def collect_each_book
    if File.exist?('links.json')
      @detail_urls = JSON.parse(File.read('links.json'))
      return @detail_urls
    end

    adv_search_url = "http://gau-lih.ge-light.com.tw/tier/front/bin/advsearch.phtml"
    visit adv_search_url
    page.find(:xpath, '//*[@id="outer"]/table[2]/tbody/tr/td/table/tbody/tr/td[2]/table/tbody/tr/td/table/tbody/tr[1]/td/table/tbody/tr/td/table/tbody/tr[2]/td/input[1]').click

    @detail_urls = []
    @errors = []
    begin
      while true
        sleep(2)
        page.all('table.searchengine-bg tr:nth-child(n+2) td:nth-child(4) a').each do |a|
          @detail_urls << a[:href]
        end

        page.all('a[href="javascript:void(clickPage(\'Next\'))"]').first.click
      end
    rescue Capybara::ElementNotFound
      File.open('links.json', 'w') {|f| f.write(JSON.pretty_generate(@detail_urls.uniq))}
      return @detail_urls.uniq
    rescue Exception => e
      File.open('links.json', 'w') {|f| f.write(JSON.pretty_generate(@detail_urls.uniq))}    
    end


  end

  def parse_each_page
    
    @books = []
    progressbar = ProgressBar.create(total: @detail_urls.count)
    @detail_urls.each do |detail_url|
      progressbar.increment
      r = RestClient.get detail_url
      ic = Iconv.new("utf-8//translit//IGNORE","big5")
      doc = Nokogiri::HTML(ic.iconv(r.to_s))

      
      # Make Book Info Lookup Table
      columns = ["作(編/譯)者 :", "出版年份 :", "ISBN :", "類別 :", "書號 :", "幾色 :", "規格 :", "發行公司 :","版權日期 :", "英文書名中譯 :", "版次 :", "頁數 :"]
      col = doc.css('.ptdet-def-td1').map {|p| p.text.strip}
      toc = doc.css('.ptdet-def-td2').map {|p| p.text.strip} 

      find_in_table = lambda do |n|
        toc[col.index(columns[n])] if !col.index(columns[n]).nil?
      end

      # Set Attributes in Table

      if !find_in_table.call(0).nil?
        author = find_in_table.call(0).gsub(/(\b著\b)|(\b編著\b)/, '').strip
        if !author
          next
        end
      end

      year = find_in_table.call(1) 
      isbn_13 = find_in_table.call(2) 
      category = find_in_table.call(3)
      book_number = find_in_table.call(4) 
      publisher = find_in_table.call(7)
      revision = find_in_table.call(10)
      pages = find_in_table.call(11)

      # Parse book name
      if doc.css('.ptdet-topic').text
        title = doc.css('.ptdet-topic').text
        if title.index(']')
          start = title.index(']') + 2
        else
          next
        end
        book_name = title[start..title.length].strip
      else
        next
      end


      # Parse book Language
      if find_in_table.call(9).nil?
        chinese_book_name = book_name
        language = "Chinese"
      else
        chinese_book_name = find_in_table.call(9).strip
        language = "English"
      end

      # Parse prices
      cover_price = doc.css('.old_price2').text
      cover_price = cover_price[2..cover_price.length]
        # has price
        if !cover_price.nil?
          cover_price = cover_price.gsub(/\,/, '')
        end

      if doc.css('.new_price').last
        price = doc.css('.new_price').last.text
        price = price[2..price.length].gsub(/\,/, '')
      end

      if doc.css('form[name="AddCart"] > table table img').first
        cover_img = doc.css('form[name="AddCart"] > table table img').first["src"]
        if cover_img.include?("Mo2/pictures")
          cover_img = nil
        end
      end

      # Parse Book Content
      if doc.css('.ptdet-text')
        content = doc.css('.ptdet-text').first.to_html
      else
        content = nil
      end      

      @books << Book.new({
        "name" => book_name,
        "chinese_book_name" => chinese_book_name,
        "language" => language,
        "cover_img" => cover_img,
        "cover_price" => cover_price,
        "price" => price,
        "author" => author,
        "year" => year,
        "isbn_13" => isbn_13,
        "category" => category,
        "content" => content,
        "book_number" => book_number,
        "publisher" => publisher,
        "revision" => revision,
        "pages" => pages,
        "url" => detail_url
      }).to_hash
    end    

    return @books
  end


end

spider = Spider.new
links = spider.collect_each_book
books = spider.parse_each_page
File.open('books.json','w'){|f| f.write(JSON.pretty_generate(books))}
binding.pry
