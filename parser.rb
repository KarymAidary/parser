require 'curb'
require 'nokogiri'
require 'csv'


def get_html url   
    begin 
        http = Curl::Easy.perform(url) do |http|
            http.headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36"
        end  
        html = Nokogiri::HTML(http.body_str)
    rescue Curl::Err::HostResolutionError 
         puts "No internet connection or invalid link"
         retry 
    end
    
end


def get_category_urls(url)
    puts "Collect category pages ...."
    category_urls = Array.new 
    while url != "" 
        html = get_html(url)
        url = html.xpath("//link[@rel='next']/@href").text.strip   
        if url != ""
            category_urls.push(url)
        end 
    end
    return category_urls
end

def get_items_urls(url)
    items_urls = Array.new
    easy_options = {:follow_location => true}
    multi_options = {:pipeline => Curl::CURLPIPE_HTTP1}
    category_urls = get_category_urls(url) 
    puts "Collect all the products ...."
    Curl::Multi.get(category_urls, easy_options, multi_options) do |url|
        html = Nokogiri::HTML(url.body_str)
        html.xpath("//div[contains(@class, 'pro_first_box')]/a/@href").each do |url|
            items_urls.push(url.text)
        end
    end
    return items_urls
end    


def parse_item(url)
    image_path = "//img[@id='bigpic']/@src"
    weight_array = "//span[contains(@class, 'radio_label')]"
    price_array  = "//span[contains(@class, 'price_comb')]"
    item_attributes = "//ul[contains(@class, 'attribute_radio_list')]//li//span"
    item_name  = "//h1[contains(@class, 'product_main_name')]"
    data = Array.new
    easy_options = {:follow_location => true}
    multi_options = {:pipeline => Curl::CURLPIPE_HTTP1}
    items_urls = get_items_urls(url)
    puts "We collect data from each product ...."
    Curl::Multi.get(items_urls, easy_options, multi_options) do |url|
        product = Hash.new
        html = Nokogiri::HTML(url.body_str)
        items = html.xpath(item_attributes).map { |item| item.content }
        options = items.each_slice(2).to_a
        html.xpath(item_name).each { |name| product[:name] = name.text.strip } 
        html.xpath(image_path).each { |img| product[:img] = img.text }
        product[:options] = options
        data.push(product)
    end 
    return data
end






while true
    puts "Enter category link: "
    url = gets.chomp
    puts "Enter file name: "
    file = gets.chomp
    if url.empty? || file.empty?
        puts "You must fill in all fields!"
        redo
    end
    t1 = Time.now
    puts "connect to #{url} ...."
    items = parse_item(url)
    puts "Write to csv ..."
    CSV.open("#{file}.csv", "wb", headers: items.first.keys) do |csv|
        items.each do |h| 
            h[:options].each do |option|
                item = Array.new
                item.push("#{h[:name]} - " + "#{option[0]}, " + "#{option[1]}, " + "#{h[:img]}")
                csv << item
            end
        end
    end
    t2 = Time.now
    delta = t2 - t1
    puts "Load time: #{delta}, Amount of products: #{items.length}"
    break
end