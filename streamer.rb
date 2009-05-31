#!/usr/local/bin/ruby
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
require 'fileutils'
require 'uri'
require 'timeout'

$LOAD_PATH.unshift("lib", "lib/sqlite3")
require 'sqlite3'
require 'id3/id3'

LOCK = '~/.streamer.lock'
TMP = '/tmp/download'
MUSIC_FOLD = ARGV.size > 0 ? ARGV[0] : '/tmp/music'

# {{{ My Helper functions
begin
FileUtils.rm_rf TMP
rescue
end
[TMP, MUSIC_FOLD].each do |folder|
  FileUtils.mkdir_p(folder.to_s)
end

def song_title(path)
  return nil unless path
  # quick title for oggs
  unless path.match(/\.mp3$/)
    return File.basename(path, File.extname(path)).gsub(/^[^A-Za-z]+\s+(\w)/, "\\1")
  end

  m = ID3::AudioFile.new(path)

  title, artist, song_title = [nil] * 3
  if m.tagID3v2 and m.tagID3v2.any?
    if m.tagID3v2["ARTIST"] and m.tagID3v2["ARTIST"]["encoding"] and m.tagID3v2["ARTIST"]["encoding"] == 0
      artist = m.tagID3v2["ARTIST"]["text"] if m.tagID3v2["ARTIST"]["text"]
    end
    if m.tagID3v2["TITLE"] and m.tagID3v2["TITLE"]["encoding"] and m.tagID3v2["TITLE"]["encoding"] == 0
      song_title = m.tagID3v2["TITLE"]["text"] if m.tagID3v2["TITLE"]["text"]
    end
  end
  if artist.nil? and title.nil? and m.tagID3v1 and m.tagID3v1.any?
    artist = m.tagID3v1["ARTIST"] if m.tagID3v1["ARTIST"]
    song_title = m.tagID3v1["TITLE"] if m.tagID3v1["TITLE"]
  end
  title = ''
  title = artist.empty? ? "" : "#{artist} - " if artist
  title += "#{song_title}" if song_title

  # Fall back on the filename with the extension stripped, and any leading numbers/punctuation stripped
  if title.empty?
    title= File.basename(path, File.extname(path)).gsub(/^[^A-Za-z]+\s+(\w)/, "\\1")
  end

  title
end

def disk_free
  a = %x{df}.split( "\n" )[1].split
  a.pop
  (100 - a.pop.to_i)
end


# 30 minutes for download
def locked_run timeout = 30 * 60 
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

# MAIN MAGIC:
puts 'streamer started.'

locked_run do
  # 1. Locked content. 

  # 1/A if not enough disk space,

  DISK_MAX = 30 # %
  # we are allowed to delete until disk free is reaching
  DISK_OK = 35 # % free space

  @db = SQLite3::Database.new(File.join(@db_folder, "rubedo.db"))
  @db.busy_timeout(200)

  if disk_free < DISK_MAX
    count = 0
    id = 'dummy'
    while disk_free < DISK_OK and count < 40 and id
      puts 'disk is over limit.'
      count += 1
      id, filename = @db.get_first_row( "select id, filename from rubedo_songs where licence is not null and id not in (select song_id from rubedo_plays) order by votes desc, last_played_at asc limit 1" )
      if id and filename
        FileUtils.rm(filename) if File.exists?(filename)
        @db.execute( 'delete from rubedo_songs where id = ?', id)
        puts "file removed: #{filename}"
      end
    end
  end

  # 1/B ok, but what about empty directories?? remove them all!

  Dir["#{MUSIC_FOLD}/**/*"].each do |dir|
    if File.directory?(dir) and Dir["#{dir}/*.*"].empty?
      FileUtils.rm_rf(dir) 
      puts "removed empty dir: #{dir}"
    end
  end

  # 2. now please download a link, 

  # 2/a prepare link and folder

  id, link, licence = @db.get_first_row( "select id,url,licence from rubedo_links order by uploaded_at") 

  unless id
    puts 'no link.'
    exit
  end

  @db.execute( "delete from rubedo_links where id = ?", id )

  link, licence = [link,licence].map do |safe|
      safe = safe.gsub(Regexp.new(URI.regexp.source.sub(/^[^:]+:/, '(http|https):'), Regexp::EXTENDED, 'n')) do
        $&
      end
    end

  puts "link found: #{link}"

  wd = Dir.pwd

  Dir.chdir TMP

  # 2/b download the link
  puts "downloading started..."
  system( "wget #{link} -q")
  puts "..finished ok"

  # 3. unzip eeeevrything!!
  puts "unzipping if any..."
  system( "unzip -o *.zip" )

  # 3/a make a fold
  dest_dir = File.join( MUSIC_FOLD, Time.now.strftime( "%Y-%m-%d-%H-%M-%S" ))

  FileUtils.mkdir_p( dest_dir )

  # 3/b copy to fold
  Dir['**/*.mp3'].each do |file|
    dest_file = File.join(dest_dir, File.basename(file))
    FileUtils.move file, dest_file
    # 4. create it in the db and make licence info
    @db.execute("insert into rubedo_songs (filename, title, play_count,licence) values(?,?,?,?)",dest_file,song_title(dest_file),0,licence)
    puts "File added: #{file}"
  end

  # 5. Remove garbage

  Dir.chdir wd
  
  FileUtils.rm_rf TMP

end
puts "finished."
