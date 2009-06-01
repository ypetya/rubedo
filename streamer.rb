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
require File.join(File.dirname(__FILE__), 'rubedo_helper.rb')

require 'sqlite3'

class Streamer

  include RubedoHelper

  # {{{ constants
  LOCK = '~/.streamer.lock'
  TMP = '/tmp/download'
  MUSIC_FOLD = ARGV.size > 0 ? ARGV[0] : '/tmp/music'
  DISK_MAX = 30
  DISK_OK = 35
  # }}}

  def initialize
    begin
    FileUtils.rm_rf TMP
    rescue
    end
    [TMP, MUSIC_FOLD].each do |folder|
      FileUtils.mkdir_p(folder.to_s)
    end

    @config = YAML::load_file(File.join(File.dirname(__FILE__), 'config.yml'))
    @log_folder = File.join(File.expand_path(File.dirname(__FILE__)), "log")
    @db_folder = File.join(File.expand_path(File.dirname(__FILE__)), "db")
  end

  def start
    locked_run(LOCK) do
      main_magic
    end
  end

  # MAIN MAGIC:
  def main_magic
    puts 'streamer started.'

    # 1/A if not enough disk space,

    #DISK_MAX = 30 # %
    # we are allowed to delete until disk free is reaching
    #DISK_OK = 35 # % free space

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

    id, link, licence = @db.get_first_row( "select id,url,licence from rubedo_links where media_type = 'audio' order by uploaded_at") 

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
      @db.execute("insert into rubedo_songs (filename, title, play_count,licence,last_played_at) values(?,?,?,?,?)",dest_file,song_title(dest_file),0,licence,'2000')
      puts "File added: #{file}"
    end

    # 5. Remove garbage

    Dir.chdir wd
    
    FileUtils.rm_rf TMP

    puts "finished."
  end
end

Streamer.new.start if __FILE__ == $0
