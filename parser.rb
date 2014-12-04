require 'nokogiri'
require 'open-uri'
require 'json'
require 'iconv'

require_relative '../book.rb'


webpages = Dir.glob('webpages/*.html')
books = []
ic = Iconv.new("utf-8//translit//IGNORE","big5")

webpages.each do |page|
  
  f = File.open(page)
  doc = Nokogiri::HTML(ic.iconv(f.read))
  
  # Make Book Info Lookup Table
  columns = ["作(編/譯)者 :", "出版年份 :", "ISBN :", "類別 :", "書號 :", "幾色 :", "規格 :", "發行公司 :","版權日期 :", "英文書名中譯 :", "版次 :", "頁數 :"]
  col = doc.css('.ptdet-def-td1').map {|p| p.text.strip}
  toc = doc.css('.ptdet-def-td2').map {|p| p.text.strip} 

  find_in_table = lambda do |n|
    toc[col.index(columns[n])] if !col.index(columns[n]).nil?
  end

  # Set Attributes

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

  #--- Parse book name
  if doc.css('.ptdet-topic').text
    title = doc.css('.ptdet-topic').text
    if title.index(']')
      start = title.index(']') + 2
    else
      next
    end
    book_name = title[start..title.length].strip
  end
  # Parse prices
  cover_price = doc.css('.old_price2').text
  cover_price = cover_price[2..cover_price.length]
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
  
  url = "http://gau-lih.ge-light.com.tw/tier/front/bin/ptdetail.phtml?Part=#{book_number}"

  # Build Book Hash
  h = {
    "name" => book_name,
    "cover_img" => cover_img,
    "cover_price" => cover_price,
    "price" => price,
    "author" => author,
    "year" => year,
    "isbn_13" => isbn_13,
    "category" => category,
    "book_number" => book_number,
    "publisher" => publisher,
    "revision" => revision,
    "pages" => pages,
    "url" => url
  }

  book = Book.new(h)
  books << book.to_hash
end

File.open('book.json', 'w') do |f|
  f.write(JSON.pretty_generate(books))
end
