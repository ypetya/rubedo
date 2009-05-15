#!/usr/bin/env ruby
#
# Kiss Péter - ypetya@gmail.com
#
# This simple script is managing wiki_to_wav, and creates new mp3-s until there is enough :) 

require 'rubygems'

# we need to ...
KEEP_FILE_COUNT = 10
# how to ...
GENERATE_WAV = File.join(File.dirname(__FILE__),'wiki_to_wav.rb 3')
# keep a safe loop count
SAFETY_COUNTER = 4

# create directories
%w{wav tmp mp3}.each do |ext|
  system("mkdir /tmp/wiki_#{ext} -p")
end

def rm file
  system("rm '#{file}' -f")
end

def encode_to_mp3 file_path
  
  # we encode to a temporary path not to broke the streaming
  tmp_file1 = "#{file_path.gsub(/wav/){'tmp'}}.wav"
  tmp_file2 = "#{file_path.gsub(/wav/){'tmp'}}.mp3"

  # converting
  # ffmpeg: please do 2 channels and normal sample rate
  system("ffmpeg -i '#{file_path}' -ac 2 -ar 44100 '#{tmp_file1}'")

  # encoding
  # lame: encode it to mp3
  system("lame '#{tmp_file1}' '#{tmp_file2}' --quiet")

  rm tmp_file1

  # and put the mp3 to the corret place
  system("mv '#{tmp_file2}' '#{file_path.gsub(/wav/){'mp3'}}'")

end

# exit if keep_limit is ok

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
