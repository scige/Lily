# coding: utf-8

class PicturesController < ApplicationController
  def index
    @url = @title = ""
  end

  def match
    @url = params[:url]
    @title = params[:title]
    begin
      @page = RestClient.get @url
      if !@title or @title.empty?
        @page =~ /<[Tt]itle>.*?<\/[Tt]itle>/
        html_title = $&
        @title = html_title[7, html_title.length-15]
      end
    rescue
      flash[:error] = "自动获取网页标题失败，请手动输入网页标题。"
      @title = ""
      @page = ""
      #redirect_to root_url and return
    end

    command = "cd get_keywords/ && LD_LIBRARY_PATH=./ && ./get_keywords -s \"#{@title}\""
    words_array = `#{command}`.chop.split

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
end
