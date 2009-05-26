#!/usr/bin/env ruby
#
# Kiss Péter - ypetya@gmail.com
#
# Streamer script:
# This simple script is downloading the media, specified by the table
# rubedo_links. And resolving optimal diskspace usage.
# This script manages the insert and remove events for available songs.
#

require 'rubygems'
require 'logger'
require 'yaml'
require 'timeout'

$LOAD_PATH.unshift("lib", "lib/sqlite3")
require 'sqlite3'

# {{{ My Helper functions
#
def disk_free
  a = %x{df}.split( "\n" )[1].split
  a.pop
  (100 - a.pop.to_i)
end

LOCK = '~/.streamer.lock'
TMP = '/tmp/download'
FileUtils.mkdir_p(TMP)

# 60 minutes for download
def locked_run timeout = 60 * 60 
  exit if File.exists?(LOCK)
  %x{touch #{LOCK}}
  begin
    Timeout::timeout(timeout) do
      yield
    end
  rescue Timeout::Error
    puts 'Too slow, sorry!!'
  end
  %x{rm #{LOCK}}
end
# }}}

@config = YAML::load_file('config.yml')
@log_folder = File.join(File.expand_path(File.dirname(__FILE__)), "log")
@db_folder = File.join(File.expand_path(File.dirname(__FILE__)), "db")

# MAIN LOGIC:
# 1. Locked content. if not enough disk space, 
DISK_MAX = 30 # %
# we are allowed to delete until disk free is reaching
DISK_OK = 40 # %
@db = SQLite3::Database.new(File.join(@db_folder, "rubedo.db"))
@db.busy_timeout(200)
if disk_free < DISK_MAX
  count = 0
  while disk_free < DISK_OK and count < 40
    count += 1
    filename = @db.get_first_value( "select filename from rubedo_songs order by votes desc, last_played_at asc limit 1" )
    FileUtils.rm(filename) if File.exists?(filename)
  end
end
# 2. now please download a link, 
# 3. unzip it, 
# 4. flush it, 
# 5. create it in the db and make licence info
