#!/bin/env ruby

require 'pathname'
$LOAD_PATH << File.join(File.dirname(Pathname.new(__FILE__).realpath),'../lib')
require 'easy_mplayer'

#
# This version derrives directly from the MPlayer class, which makes
# the adding of callbacks easier.
#

class MyApp < MPlayer
  def show(msg)
    puts 'EXAMPLE<callbacks> ' + msg
  end

  def process_key(key)
    case key
    when 'q', 'Q' then stop
    when " "      then pause_or_unpause
    when "\e[A"   then seek_forward(60)     #    UP arrow
    when "\e[B"   then seek_reverse(60)     #  DOWN arrow
    when "\e[C"   then seek_forward         # RIGHT arrow
    when "\e[D"   then seek_reverse         #  LEFT arrow
    end
  end

  def read_keys
    x = IO.select([$stdin], nil, nil, 0.1)
    return if !x or x.empty?
    @key ||= ''
    @key << $stdin.read(1)
    if @key[0,1] != "\e" or @key.length >= 3
      process_key(@key)
      @key = ''
    end
  end

  def run!
    begin
      play
      
      tty_state = `stty -g`
      system "stty cbreak -echo"  
      read_keys while running?
    ensure
      system "stty #{tty_state}"
    end
  end
  
  def initialize(file)
    super( :path => file )
  end
  
  callback :audio_stats do
    show "Audio is: "
    show "  ->    sample_rate: #{stats[:audio_sample_rate]} Hz"
    show "  -> audio_channels: #{stats[:audio_channels]}"
    show "  ->   audio_format: #{stats[:audio_format]}"
    show "  ->      data_rate: #{stats[:audio_data_rate]} kb/s"
  end

  callback :video_stats do
    show "Video is: "
    show "  -> fourCC: #{stats[:video_fourcc]}"
    show "  -> x_size: #{stats[:video_x_size]}"
    show "  -> y_size: #{stats[:video_y_size]}"
    show "  ->    bpp: #{stats[:video_bpp]}"
    show "  ->    fps: #{stats[:video_fps]}"
  end

  callback :position do |position|
    show "Song position percent: #{position}%"
  end

  callback :played_seconds do |val|
    total  = stats[:total_time]
    show "song position in seconds: #{val} / #{total}"
  end

  callback :pause, :unpause do |pause_state|
    show "song state: " + (pause_state ? "PAUSED!" : "RESUMED!")
  end

  callback :play do
    show "song started!"
  end

  callback :stop do
    show "song ended!"
    puts "final stats were: #{stats.inspect}"
  end
end

# play a file from the command line
raise "usage: #{$0} <file>" if ARGV.length != 1

MyApp.new(ARGV[0]).run!
