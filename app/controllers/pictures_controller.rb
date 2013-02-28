# coding: utf-8
require 'iconv'

class PicturesController < ApplicationController
  def index
    @url = @title = ""
  end

  def match
    @url = params[:url]
    @title = params[:title]
    #binding.pry
    begin
      @page = RestClient.get @url
      charset = get_charset(@page)
      @page = Iconv.conv('UTF-8//IGNORE', charset, @page)

      if !@title or @title.empty?
        @title = RestClient.post "http://10.230.225.18:4567/", :url=>@url
        @title = Iconv.conv('UTF-8//IGNORE', 'UTF-8//IGNORE', @title)
      end

      if !@title or @title.empty?
        @title = get_title(@page)
      end
    rescue
      flash.now[:error] = "自动获取网页标题失败，请手动输入网页标题。"
      @title = ""
      @page = ""
      #redirect_to root_url and return
    end

    command = "cd get_keywords/ && LD_LIBRARY_PATH=./ && ./get_keywords -s \"#{@title}\""
    words_string = `#{command}`
    words_array = words_string.chop.split

    redis = Redis.new
    @redis_kv = []

    words_array.sort!

    words_array.delete_if do |word|
      word.length <= 1 or word.bytesize <= 3
    end

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
end
