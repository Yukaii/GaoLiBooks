require 'json'

class Book
  attr_accessor :name, :author, :price, :cover_price, :cover_img, 
                :isbn_10, :isbn_13, :book_number, :language, :author_intro, 
                :content, :year, :publisher, :edition, :revision, :pages, 
                :type, :category, :url, :copyright_date, :chinese_book_name

  # attr_accessor :attributes

  def initialize(h)
    @attributes = [:name, :author, :price, :cover_price, :cover_img, 
                   :isbn_10, :isbn_13, :book_number, :language, :author_intro, 
                   :content, :year, :publisher, :edition, :revision, :pages, 
                   :type, :category, :url, :copyright_date, :chinese_book_name]
    
    h.each {|k,v| send("#{k}=",v)}
  end
  
  def to_hash
    @data = Hash[ @attributes.map {|d| [d.to_s, self.instance_variable_get('@'+d.to_s)]} ]
  end

  def to_json
    JSON.pretty_generate @data
  end
end