#!/bin/env ruby

require 'pathname'
$LOAD_PATH << File.join(File.dirname(Pathname.new(__FILE__).realpath),'../lib')
require 'easy_mplayer'

# play a file from the command line
raise "usage: #{$0} <file>" if ARGV.length != 1
$file = ARGV[0]

#
# This walks through some of the basic commands to
# control already-playing media
#

def show(msg)
  puts 'EXAMPLE<basic> ' + msg
end

def command(msg)
  show "2"
  sleep 1
  show "1"
  sleep 1
  show "Command( #{msg} )"
  yield
end

show "Create the player object for: #{$file}"
mplayer = MPlayer.new( :path => $file )

show "Spawning the mplayer process!"
mplayer.play

# set this true to see various basic commands
# set it false to see the basic "wait until the file is done" check
show_basic_commands = true

if show_basic_commands
  command "pause" do
    mplayer.pause
  end

  command "pause (again, to resume)" do
    mplayer.unpause
  end

  command "seek to 25%" do
    mplayer.seek_to_percent 25.0
  end

  command "seek back to 10%" do
    mplayer.seek_to_percent 10.0
  end

  command "stop" do
    mplayer.stop
  end
  
else
  show "Waiting for the file to finish..."
  sleep 1 while mplayer.playing?
end


show "All done!"
