# coding: utf-8
require 'iconv'

class PicturesController < ApplicationController
  def initialize
    super
    @url_keywords_hash = {}
    File.open("data/sample.20130312") do |file|
      file.each_line do |line|
        parts = line.chop.split("\t")
        if parts.size != 3
          next
        end
        url = parts[0]
        title = parts[1]
        keywords = parts[2]

        if url.empty? or title.empty? or keywords.empty?
          next
        end

        temp_hash = {:title=>title, :keywords=>keywords}
        @url_keywords_hash[url] = temp_hash
      end
    end
  end

  def index
    @url = ""
  end

  def surfer
    @url = ""
  end

  def batch_match
    @urls = params[:urls].strip.split("\r\n")
    @urls.delete_if do |url|
      url.empty?
    end

    @batch_match_array = []
    @urls.each do |url|
      temp_hash = @url_keywords_hash[url]
      if !temp_hash
        result_hash = {:url=>url, :title=>"", :aliguess_keywords=>[], :valid_keywords=>[], :match_key=>"", :match_oss=>"default.jpg"}
        @batch_match_array << result_hash
        next
      end
      result_hash = {:url=>url, :title=>temp_hash[:title]}

      words_array = temp_hash[:keywords].split
      result_hash[:aliguess_keywords] = words_array.dup

      # 第一维度按词的长度排序，第二为维度按字母序排序
      words_array.sort! do |left, right|
        (right.length <=> left.length).nonzero? || (right <=> left)
      end

      result_hash[:valid_keywords] = words_array.dup

      redis_kv = create_redis_kv(words_array)

      match_key = ""
      match_oss = "default.jpg"
      redis_kv.each do |item|
        if item[1]
          match_key = item[0]
          match_oss = "http://recimg.cdn.aliyuncs.com/" + item[1]
          break
        end
      end

      result_hash[:match_key] = match_key
      result_hash[:match_oss] = match_oss
      @batch_match_array << result_hash
    end
  end

  def match
    @url = normalize(params[:url])
    @input_title = params[:title]
    @domain = get_domain(@url)
    #binding.pry
    begin
      @page = RestClient.get @url
      charset = get_charset(@page)
      @page = Iconv.conv('UTF-8//IGNORE', charset, @page)

      @use_title = ""
      if @input_title.empty?
        @article_title = RestClient.post "http://10.230.225.18:4567/", :url=>@url
        @article_title = Iconv.conv('UTF-8//IGNORE', 'UTF-8//IGNORE', @article_title)

        @html_title = get_title(@page)

        if @article_title and !@article_title.empty?
          @use_title = @article_title
        elsif @html_title and !@html_title.empty?
          @use_title = @html_title
        else
          @use_title = @input_title
        end
      else
        @use_title = @input_title
      end

    rescue
      flash.now[:error] = "自动获取网页标题失败，请手动输入网页标题。"
      if @article_title and !@article_title.empty?
        @use_title = @article_title
      elsif @input_title and !@input_title.empty?
        @use_title = @input_title
      else
        @use_title = ""
      end
      @page = ""
      #redirect_to root_url and return
    end

    command = "cd ./get_result_filter/ && LD_LIBRARY_PATH=./ ./get_resultfilter -s \"#{@use_title}\" \"#{@domain}\""
    @trim_title = `#{command}`.chop

    command = "cd ./get_keywords/ && LD_LIBRARY_PATH=./ ./get_keywords -s \"#{@trim_title}\" \"#{@domain}\""
    words_string = `#{command}`
    words_array = words_string.chop.split

    @aliguess_keywords = words_array.dup

    # 第一维度按词的长度排序，第二为维度按字母序排序
    words_array.sort! do |left, right|
      (right.length <=> left.length).nonzero? || (right <=> left)
    end

    #words_array.delete_if do |word|
    #  word.length <= 1 or word.bytesize <= 3
    #end

    @valid_keywords = words_array.dup

    @redis_kv = create_redis_kv(words_array)

    @match_oss = "default.jpg"
    @redis_kv.each do |item|
      if item[1]
        @match_key = item[0]
        @match_oss = "http://recimg.cdn.aliyuncs.com/" + item[1]
        break
      end
    end
  end

  private

  def create_redis_kv(words_array)
    redis = Redis.new(:port=>8378)
    redis_kv = []
    if words_array.length == 3
      redis_key = words_array.join(" ")
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]

      redis_key = words_array[0] + " " + words_array[1]
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]
      redis_key = words_array[0] + " " + words_array[2]
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]
      redis_key = words_array[1] + " " + words_array[2]
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]

      redis_key = words_array[0]
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]
      redis_key = words_array[1]
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]
      redis_key = words_array[2]
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]
    elsif words_array.length == 2
      redis_key = words_array.join(" ")
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]

      redis_key = words_array[0]
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]
      redis_key = words_array[1]
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]
    else
      redis_key = words_array[0]
      redis_kv << [redis_key, redis.hget(redis_key, "oss")]
    end
    return redis_kv
  end

  def get_charset(page)
    #binding.pry
    pos_body = page.index("<body")
    if pos_body
      head = page[0...pos_body]
    else
      head = page
    end
    if head.index("charset=gb2312") or
       head.index("charset=GB2312") or
       head.index("charset=\"gb2312\"") or
       head.index("charset=\"GB2312\"")
      'GB2312//IGNORE'
    elsif head.index("charset=gbk") or
          head.index("charset=GBK") or
          head.index("charset=\"gbk\"") or
          head.index("charset=\"GBK\"")
      'GBK//IGNORE'
    else
      'UTF-8//IGNORE'
    end
  end

  def get_title(page)
    #binding.pry
    page =~ /<title.*?>.*?<\/title>/i
    html_title = $&
    if !html_title
      return ""
    end
    pos_begin = html_title.index(">")
    pos_end = html_title.index("</")
    if pos_begin and pos_end
      html_title[pos_begin+1...pos_end]
    else
      ""
    end

    #pos_begin = page.index("<title>")
    #pos_end = page.index("</title>")
    #page[pos_begin+7...pos_end]
  end

  def normalize(url)
    normalized_url = url
    if !url.index("http://")
      normalized_url = "http://" + url
    end
    pos_begin = normalized_url.index('//')
    pos_end = normalized_url.index('/', pos_begin+2)
    if !pos_end
      normalized_url += "/"
    end
    return normalized_url
  end

  def get_domain(url)
    begin
      pos_begin = url.index('//')
      pos_end = url.index('/', pos_begin+2)
      host = url[pos_begin+2...pos_end]
      domain = host.split('.')[-2..-1].join('.')
      if domain == "com.cn"
        domain = host.split('.')[-3..-1].join('.')
      end
      return domain
    rescue
      return ""
    end
  end
end
