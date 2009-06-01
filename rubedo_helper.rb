
# {{{ My helper stuff
require 'logger'
require 'yaml'
require 'fileutils'
require 'uri'
require 'timeout'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "lib"))

require 'id3/id3'

module RubedoHelper

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
  def locked_run( lock_file, timeout = 30 * 60 )
    exit if File.exists?(lock_file)
    %x{touch #{lock_file}}
    begin
      Timeout::timeout(timeout) do
        yield
      end
    rescue Timeout::Error
      puts 'Too slow, sorry!!'
    end
    %x{rm #{lock_file}}
  end

  def rm filename
    FileUtils.rm(filename) if File.exists?(filename)
  end

  def encode_to_mp3 file_path
    
    # we encode to a temporary path not to broke the streaming
    tmp_file1 = "#{file_path.gsub(/wav/){'tmp'}}.wav"
    tmp_file2 = "#{file_path.gsub(/wav/){'tmp'}}.mp3"
    title_file = "#{file_path}.title"
    # converting
    # ffmpeg: please do 2 channels and normal sample rate
    system("ffmpeg -i '#{file_path}' -ac 2 -ar 44100 '#{tmp_file1}'")

    title = File.read( title_file ).strip

    # removeing title data... :)
    rm title_file

    # encoding
    # lame: encode it to mp3
    system("lame '#{tmp_file1}' '#{tmp_file2}' --quiet --tt \"#{title.gsub(/["]/){''}}\"")

    rm tmp_file1

    # and put the mp3 to the corret place
    system("mv '#{tmp_file2}' '#{file_path.gsub(/wav/){'mp3'}}'")

  end
end
# }}}

