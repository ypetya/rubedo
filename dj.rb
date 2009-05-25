#!/usr/local/bin/ruby

# stdlib
require 'rubygems'
require 'logger'
require 'yaml'

# extra
$LOAD_PATH.unshift("lib", "lib/sqlite3")
require 'shout'
require 'sqlite3'
require 'id3/id3'

class DJ

  def initialize
    @config = YAML::load_file('config.yml')
    @log_folder = File.join(File.expand_path(File.dirname(__FILE__)), "log")
    @db_folder = File.join(File.expand_path(File.dirname(__FILE__)), "db")

    @shout = Shout.new
    @shout.host = @config["icecast"]["server"]
    @shout.port = @config["icecast"]["port"]
    @shout.user = @config["icecast"]["username"]
    @shout.pass = @config["icecast"]["password"]
    @shout.mount = @config["icecast"]["mount"]
    @shout.name = @config["radio_name"]
    # format can be changed per-song, but defaults to MP3
    @shout.format = Shout::MP3

    FileUtils.mkdir_p(@db_folder)
    @db = SQLite3::Database.new(File.join(@db_folder, "rubedo.db"))
    @db.busy_timeout(200)

    @mode = :user

    if @config["dj_log_file"] and @config["dj_log_file"].any?
      FileUtils.mkdir_p(@log_folder)
      @log = Logger.new(File.join(@log_folder, @config["dj_log_file"]), 'daily')
      @log.info("DJ started, begin logging.")
    end
  end

  def start
    connect
    play_songs
  end

  def connect
    begin
      @shout.connect
    rescue
      log.fatal "Couldn't connect to Icecast server." if log
      exit
    end
  end

  def play_songs
    loop do
      song = next_song!
      if song
        play(song, song[1])
        mark_done! song
      else
				song = random_song
        play(song, song[1])
        system("rm '#{song[1]}' -f") if song[1] =~ /wiki_mp3/
      end
    end
  end

  def handle_history title
    
    while db.get_first_value( "select count(*) from rubedo_histories" ).to_i > 29
      id = db.get_first_row( "select id from rubedo_histories order by id asc limit 1")
      db.execute( "delete from rubedo_histories where id = ?", id )
    end

    db.execute("insert into rubedo_histories (title,played_at) values (?,?) ", title, Time.now)
  end

  def play(song,song_path = nil)
    # a nil song means there are no songs at all, so just slowly loop until one comes along
    if song.nil?
      sleep 500
      return nil
    end

    id, path, title = song
    song_path ||= File.join( music_folder, path)

    unless File.exists?(song_path)
      log.error "File didn't exist, moving on to the next song.  Full path was #{song_path}" if log
      return
    end

    # set MP3 or OGG format
    format = @shout.format
    case File.extname(path)
    when ".mp3"
      format = Shout::MP3
    when ".ogg"
      format = Shout::OGG
    else
      format = Shout::MP3
    end

    if format != @shout.format
      log.info "Switching stream formats, re-connecting." if log
      @shout.disconnect
      @shout.format = format
      @shout.connect
    end

    # allow interrupts?
    seek_interrupt = (@mode == :dj and @config["interrupt_empty_queue"])

    File.open(song_path) do |file|
      # set metadata (MP3 only)
      if @shout.format == Shout::MP3
        metadata = ShoutMetadata.new
        metadata.add 'song', title
        metadata.add 'filename', File.basename(path)
        @shout.metadata = metadata
      end

      log.info "Playing #{title}!" if log
      
      handle_history title

      while data = file.read(16384)
        begin
          @shout.send data
          break if seek_interrupt and next_song
          @shout.sync
        rescue
          log.error "Error connecting to Icecast server.  Don't worry, reconnecting." if log
          @shout.disconnect
          @shout.connect
        end
      end
    end
  end

  def get_songs_for_random
    unless defined? @last_played
      @last_played = nil
      @wiki_played = 0
    end
    wiki = Dir["/tmp/wiki_mp3/**/*.{mp3,ogg}"]
    songs = Dir["#{music_folder}/**/*.{mp3,ogg}"]

    if not wiki.empty? and ( @last_played != :wiki or @wiki_played < @config['dj']['wiki_play_max'])
      @wiki_played = 0 unless @last_played == :wiki 
      @last_played = :wiki
      @wiki_played += 1
      return wiki
    elsif not songs.empty?
      @last_played = :song
      return songs
    end
    []
  end

  # takes a random song off of the filesystem, making this source client independent of any web frontend
  def random_song
    @mode = :dj

    songs = get_songs_for_random
    
    path = songs[rand(songs.size)]

    if not path or path.empty?
      nil
    else
      [0, path, song_title(path)]
    end
  end

  # This returns the filename of the next song to be played.  By default, it will NOT also set this as the next song to be played.  To do this, call next_song!
  def next_song(set_as_playing = false)
    @mode = :user

    play_id, filename, title, song_id = nil
    begin
      # this query will get a song which was cut off while playing first, and failing that, will get the next song on the queue which hasn't been played
      play_id, filename, title, song_id = db.get_first_row "select id, filename, title, song_id from rubedo_plays where queued_at IS NOT NULL order by queued_at asc limit 1"
      return nil unless play_id
    rescue
      log.error "Error at some point during finding #{'(and setting) ' if set_as_playing}next song.  Filename was: #{filename}\n#{$!}" if log
      return nil
    end

    mark_start!(play_id, song_id) if set_as_playing

    [play_id, filename, title]
  end

  def next_song!
    next_song(true)
  end

  # these functions are only called when the song was queued by a user (@mode == :user)
  def mark_start!(play_id, song_id)
    begin
      db.execute("update rubedo_plays set played_at = ?, queued_at = NULL WHERE id = ?", Time.now, play_id)
      count = db.get_first_value("select play_count from rubedo_songs where id = ?", song_id)
      db.execute("update rubedo_songs set last_played_at = ?, play_count = ? WHERE id = ?", Time.now, count.to_i + 1, song_id)
    rescue
      log.error "Error during marking a song as beginning.  Song ID: #{song_id}"
    end
  end

  def mark_done!(song)
    begin
      db.execute("delete from rubedo_plays where id = ?", song[0])
    rescue
      log.error "Error marking song as done. Play ID: #{song[0]}"
    end
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
    title = artist.empty? ? "" : "#{artist} - " if artist
    title += "#{song_title}" if song_title

    # Fall back on the filename with the extension stripped, and any leading numbers/punctuation stripped
    if title.emtpy?
      title= File.basename(path, File.extname(path)).gsub(/^[^A-Za-z]+\s+(\w)/, "\\1")
    end

    title
  end

  def log; @log; end
  def db; @db; end

  def music_folder
    music = @config["music_folder"]
    File.exists?(music) ? music : "./music"
  end

end

DJ.new.start if __FILE__ == $0
