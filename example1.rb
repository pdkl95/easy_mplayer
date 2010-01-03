#!/bin/env ruby

$LOAD_PATH << 'lib'
require 'easy_mplayer'

raise "usage: #{$0} <file>" if ARGV.length != 1
$file = ARGV[0]

puts "EXAMPLE: Create the player object"
mplayer = MPlayer.new

puts "EXAMPLE: setting target as: #{$file}"
mplayer.path = $file

puts "EXAMPLE: spawning the mplayer process!"
mplayer.play!

puts "EXAMPLE: waiting for the file to finish..."
sleep 10
sleep 1 while mplayer.playing?

puts "EXAMPLE: all done!"
