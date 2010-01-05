#!/bin/env ruby

require 'pathname'
$LOAD_PATH << File.join(File.dirname(Pathname.new(__FILE__).realpath),'../lib')
require 'easy_mplayer'

class MyApp
  def show(msg)
    puts 'EXAMPLE<callbacks> ' + msg
  end

  def process_key(key)
    case key
    when 'q', 'Q' then @mplayer.stop
    when " "      then @mplayer.pause_or_unpause
    when "\e[A"   then @mplayer.seek_forward(60)
    when "\e[B"   then @mplayer.seek_reverse(60)
    when "\e[C"   then @mplayer.seek_forward
    when "\e[D"   then @mplayer.seek_reverse
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
      @mplayer.play
      
      tty_state = `stty -g`
      system "stty cbreak -echo"  
      read_keys while @mplayer.running?
    ensure
      system "stty #{tty_state}"
    end
  end
  
  def initialize(file)
    @mplayer = MPlayer.new( :path => file )

#    @mplayer.callback :position do |current_time|
#      total = @mplayer.stats[:total_time]
#      show "Song position: #{current_time} / #{total} seconds"
#    end

#    @mplayer.callback :pause, :unpause do
#      show "song state: " + (@mplayer.paused? ? "PAUSED!" : "RESUMED!")
#    end

#    @mplayer.callback :stop do
#      show "song ended!"
#    end
  end
end

# play a file from the command line
raise "usage: #{$0} <file>" if ARGV.length != 1

MyApp.new(ARGV[0]).run!
