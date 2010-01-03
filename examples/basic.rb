#!/bin/env ruby

require 'pathname'
$LOAD_PATH << File.join(File.dirname(Pathname.new(__FILE__).realpath),'../lib')
require 'easy_mplayer'

# play a file from the command line
raise "usage: #{$0} <file>" if ARGV.length != 1
$file = ARGV[0]

def show(msg)
  puts 'EXAMPLE: ' + msg
end

show "Create the player object"
mplayer = MPlayer.new

show "Setting target as: #{$file}"
mplayer.path = $file

show "Spawning the mplayer process!"
mplayer.play!

show "Waiting for the file to finish..."
sleep 10
sleep 1 while mplayer.playing?

show "All done!"
