#!/usr/bin/env ruby
#
# Kiss Péter - ypetya@gmail.com
#
# This simple script is managing wiki_to_wav, and creates new mp3-s until there is enough :) 

require 'rubygems'

KEEP_FILE_COUNT = 5

GENERATE_WAV = 'wiki_to_wav.rb 3'
GENERATE_MP3 = 'lame *.wav'

system('mkdir /tmp/wiki_wav -pf')
system('mkdir /tmp/wiki_mp3 -pf')

# exit if keep_limit is ok

while %x{ls /tmp/wiki_mp3 -la | wc -L}.to_i < KEEP_FILE_COUNT do
  system( GENERATE_WAV )
	Dir["/tmp/wiki_wav/*.wav"].each do |file|
		system("lame /tmp/wiki_wav/#{file} /tmp/wiki_mp3/#{file.gsub(/wav/){'mp3'}}")
		system("rm /tmp/wiki_wav/#{file}")
		puts '.'
	end
end
