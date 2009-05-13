#!/usr/bin/env ruby
#
# Kiss Péter - ypetya@gmail.com
#
# This simple script is managing wiki_to_wav, and creates new mp3-s until there is enough :) 

require 'rubygems'

KEEP_FILE_COUNT = 10

GENERATE_WAV = File.join(File.dirname(__FILE__),'wiki_to_wav.rb 3')
SAFETY_COUNTER = 4

system('mkdir /tmp/wiki_wav -p')
system('mkdir /tmp/wiki_mp3 -p')

# exit if keep_limit is ok

#failsafe :)
Dir["/tmp/wiki_wav/*.wav"].each do |file|
	system("lame '#{file}' '#{file.gsub(/wav/){'mp3'}}' --quiet -b 128 --resample 44.1")
	system("rm '#{file}' -f")
	print '+'
end

i = 0
while((Dir["/tmp/wiki_mp3/*.mp3"].size < KEEP_FILE_COUNT) and i < SAFETY_COUNTER) do
  system( GENERATE_WAV )
	Dir["/tmp/wiki_wav/*.wav"].each do |file|
		system("lame '#{file}' '#{file.gsub(/wav/){'mp3'}}' --quiet -b 128 -resample 44.1")
		system("rm '#{file}' -f")
		print '.'
	end
  i += 1
end

puts 'generate _ok'
