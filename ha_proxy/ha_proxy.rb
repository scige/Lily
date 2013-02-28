require 'sinatra'
#require 'iconv'

post '/' do
    url = params[:url]
    get_article_title(url)
end

def match_at(ha_string)
    if ha_string =~ /<ARTICLE_TITLE><!\[CDATA\[.*?\]\]><\/ARTICLE_TITLE>/
        at_temp = $&
        at_temp[24..at_temp.length-20]
        #at_string = at_temp[24..at_temp.length-20]
        #Iconv.conv('UTF-8//IGNORE', 'UTF-8//IGNORE', at_string)
    end
end

def get_article_title(url)
    commands = []
    commands << ["ha se -q \"cluster=cnzz_rt&&config=start:0,hit:1,sourceid:1&&query=pk:'#{url}'\" -a http://10.249.59.15:10003", "cnzz_rt"]
    commands << ["ha se -q \"cluster=cnzz_inc&&config=start:0,hit:1,sourceid:1&&query=pk:'#{url}'\" -a http://10.249.59.15:10003", "cnzz_inc"]
    commands << ["ha se -q \"cluster=galaxy&&config=start:0,hit:1&&query=pk:'#{url}'\" -a http://10.249.46.43:10003", "galaxy"]
    commands << ["ha se -q \"cluster=bigindex&&config=start:0,hit:1&&query=pk:'#{url}'\" -a http://172.21.24.14:10003", "bigindex"]

    commands.each do |command|
        ha_string = `#{command[0]}`
        article_title = match_at(ha_string)
        puts "debug: index[#{command[1]}], article_title: #{article_title}"
        if article_title
            return article_title
        end
    end

    return ""
end

