#!/usr/bin/env ruby
#
# Kiss Péter - ypetya@gmail.com
#
# This simple script is managing wiki_to_wav, and creates new mp3-s until there is enough :) 

require 'rubygems'

KEEP_FILE_COUNT = 10

GENERATE_WAV = 'wiki_to_wav.rb 3'
GENERATE_MP3 = 'lame *.wav'

system('mkdir /tmp/wiki_wav -p')
system('mkdir /tmp/wiki_mp3 -p')

# exit if keep_limit is ok

#failsafe :)
Dir["/tmp/wiki_wav/*.wav"].each do |file|
	system("lame '#{file}' '#{file.gsub(/wav/){'mp3'}}' --quiet")
	system("rm '#{file}' -f")
	print '+'
end

while Dir["/tmp/wiki_mp3/*.mp3"].size < KEEP_FILE_COUNT do
  system( GENERATE_WAV )
	Dir["/tmp/wiki_wav/*.wav"].each do |file|
		system("lame '#{file}' '#{file.gsub(/wav/){'mp3'}}' --quiet")
		system("rm '#{file}' -f")
		print '.'
	end
end

puts 'generate _ok'
