require 'curb'
require 'nokogiri'
require 'csv'

$image_path = "//img[@id='bigpic']/@src"
$item_attributes = "//ul[contains(@class, 'attribute_radio_list')]//li//span"
$item_name  = "//h1[contains(@class, 'product_main_name')]"


class Parser 
    @@easy_options = {:follow_location => true}
    @@multi_options = {:pipeline => Curl::CURLPIPE_HTTP1}
    attr_accessor :url

    def initialize()
        @url = nil
    end
    
    def get_url 
        @url
    end
    
    def url=(url)
        @url = url
    end

    def http_request
        http = Curl::Easy.perform(@url) do |http|
            http.headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36"
        end  
    end

    def multi_request(*urls)
        htmls = Array.new
        Curl::Multi.get(*urls, @@easy_options, @@multi_options) do |url|
            htmls.push(Nokogiri::HTML(url.body_str))
        end
        return htmls
    end

    def get_html
        Nokogiri::HTML(http_request.body_str)
    end

    def get_item (item)
        get_html.xpath(item).text.strip
    end
end



def get_category_urls 
    parser = Parser.new
    parser.url = "https://www.petsonic.com/snacks-huesos-para-perros/" 
    puts "Collect category pages ...."
    category_urls = Array.new 
    while parser.url != "" 
        category_urls.push(parser.url)
        parser.url = parser.get_item("//link[@rel='next']/@href")
    end
    return category_urls
end

print get_category_urls

def get_items_urls
    parser = Parser.new
    items_urls = Array.new
    puts "Collect all the products ...."
    category_urls = parser.multi_request(get_category_urls)
    category_urls.each do |html|
        html.xpath("//div[contains(@class, 'pro_first_box')]/a/@href").each do |url|
            items_urls.push(url.text)
        end
    end
    return items_urls
end    


def parse_item
    data = Array.new
    parser = Parser.new
    puts "We collect data from each product ...."
    items_urls = parser.multi_request(get_items_urls)
    items_urls.each do |html|
        product = Hash.new
        items = html.xpath($item_attributes).map { |item| item.content }
        options = items.each_slice(2).to_a
        html.xpath($item_name).each { |name| product[:name] = name.text.strip } 
        html.xpath($image_path).each { |img| product[:img] = img.text }
        product[:options] = options
        data.push(product)
    end 
    return data
end  






t1 = Time.now
puts parse_item
t2 = Time.now
delta = t2 - t1
puts "Load time: #{delta}"
