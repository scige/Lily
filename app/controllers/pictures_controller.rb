# coding: utf-8
require 'iconv'

class PicturesController < ApplicationController
  def index
    @url = ""
  end

  def match
    @url = params[:url]
    @title = params[:title]
    @domain = get_domain(@url)
    #binding.pry
    begin
      @page = RestClient.get @url
      charset = get_charset(@page)
      @page = Iconv.conv('UTF-8//IGNORE', charset, @page)

      @article_title = RestClient.post "http://10.230.225.18:4567/", :url=>@url
      @article_title = Iconv.conv('UTF-8//IGNORE', 'UTF-8//IGNORE', @article_title)

      @html_title = get_title(@page)

      if @article_title and !@article_title.empty?
        @title = @article_title
      elsif @html_title and !@html_title.empty?
        @title = @html_title
      end

    rescue
      flash.now[:error] = "自动获取网页标题失败，请手动输入网页标题。"
      @title = ""
      @page = ""
      #redirect_to root_url and return
    end

    command = "cd get_keywords/ && LD_LIBRARY_PATH=./ && ./get_keywords -s \"#{@title}\" \"#{@domain}\""
    words_string = `#{command}`
    words_array = words_string.chop.split

    @aliguess_keywords = words_array.join("  ")

    redis = Redis.new
    @redis_kv = []

    words_array.sort!

    words_array.delete_if do |word|
      word.length <= 1 or word.bytesize <= 3
    end

    @valid_keywords = words_array.join("  ")

    if words_array.length == 3
      redis_key = words_array.join(" ")
      @redis_kv << [redis_key, redis.get(redis_key)]

      redis_key = words_array[0] + " " + words_array[1]
      @redis_kv << [redis_key, redis.get(redis_key)]
      redis_key = words_array[0] + " " + words_array[2]
      @redis_kv << [redis_key, redis.get(redis_key)]
      redis_key = words_array[1] + " " + words_array[2]
      @redis_kv << [redis_key, redis.get(redis_key)]

      redis_key = words_array[0]
      @redis_kv << [redis_key, redis.get(redis_key)]
      redis_key = words_array[1]
      @redis_kv << [redis_key, redis.get(redis_key)]
      redis_key = words_array[2]
      @redis_kv << [redis_key, redis.get(redis_key)]
    elsif words_array.length == 2
      redis_key = words_array.join(" ")
      @redis_kv << [redis_key, redis.get(redis_key)]

      redis_key = words_array[0]
      @redis_kv << [redis_key, redis.get(redis_key)]
      redis_key = words_array[1]
      @redis_kv << [redis_key, redis.get(redis_key)]
    else
      redis_key = words_array[0]
      @redis_kv << [redis_key, redis.get(redis_key)]
    end

    @oss_url = ""
    @redis_kv.each do |item|
      if item[1]
        @match_key = item[0]
        @match_oss = "http://recimg.cdn.aliyuncs.com/" + item[1]
        break
      end
    end
  end

  private

  def get_charset(page)
    pos_body = page.index("<body")
    head = page[0...pos_body]
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
    page =~ /<[Tt]itle.*?>.*?<\/[Tt]itle>/
    html_title = $&
    pos_begin = html_title.index(">")
    pos_end = html_title.index("</")
    html_title[pos_begin+1...pos_end]

    #pos_begin = page.index("<title>")
    #pos_end = page.index("</title>")
    #page[pos_begin+7...pos_end]
  end

  def get_domain(url)
    begin
      pos_begin = url.index('//')
      pos_end = url.index('/', pos_begin+2)
      host = url[pos_begin+2...pos_end]
      host.split('.')[-2..-1].join('.')
    rescue
      return ""
    end
  end
end
