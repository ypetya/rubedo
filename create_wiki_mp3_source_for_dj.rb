#!/usr/bin/env ruby
#
# Kiss Péter - ypetya@gmail.com
#
# This simple script is managing wiki_to_wav, and creates new mp3-s until there is enough :) 

require 'rubygems'
require File.join(File.dirname(__FILE__), 'rubedo_helper.rb')

class CreateWiki

  include RubedoHelper

  # {{{ constants
  # we need to ...
  KEEP_FILE_COUNT = 20
  # how to ...
  GENERATE_WAV = File.join(File.dirname(__FILE__),'wiki_to_wav.rb 3')
  # keep a safe loop count
  SAFETY_COUNTER = 4
  # and use this file to lockourselves
  LOCK = '~/.wiki.lock'
  # }}}

  # create directories
  def initialize
    %w{wav tmp mp3}.each do |ext|
      system("mkdir /tmp/wiki_#{ext} -p")
    end
  end

  def start
    locked_run(LOCK, 10 * 60 ) do 
      main_magic
    end
  end

  def main_magic
    # are there some wav garbage??
    Dir["/tmp/wiki_wav/*.wav"].each do |file|
      
      encode_to_mp3 file

      rm file

      print '+'
    end

    i = 0
    while((Dir["/tmp/wiki_mp3/*.mp3"].size < KEEP_FILE_COUNT) and i < SAFETY_COUNTER) do
      system( GENERATE_WAV )
      Dir["/tmp/wiki_wav/*.wav"].each do |file|
        
        encode_to_mp3 file
        
        rm file
        
        print '.'
      end
      i += 1
    end

    puts 'generate _ok'
  end
end

CreateWiki.new.start if __FILE__ == $0
