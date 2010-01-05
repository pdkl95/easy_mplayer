class MPlayer
  # a blocking version of #play for trivial uses. It returns only
  # after the mplayer process finally terminates itself
  def play_to_end
    play
    sleep 1 while running?
  end
  
  # spawn the mplayer process, which also starts the media playing. It
  # is requires that #opts[:path] point to a valid media file
  def play
    stop if running?
    
    info "PLAY: #{opts[:path]}"
    worker.startup!
  end
  
  # kill off the mplayer process. This invalidates any running media,
  # though it can be restarted again with another call to #play
  def stop
    info "STOP!"
    @worker.shutdown! if @worker
  end
  
  # pause playback if we are running
  def pause
    return if paused?
    info "PAUSE!"
    send_command :pause
    @paused = true
    callback! :pause, true
  end
  
  # opposite of #pause
  def unpause
    return unless paused?
    info "UNPAUSE!"
    send_command :pause
    @paused = false
    callback! :unpause, false
  end
  
  # use this instead of #pause or #unpause, and the flag will be
  # toggled with each call
  def pause_or_unpause
    paused? ? unpause : pause
  end
  
  # Seek to an absolute position in a file, by percent of the total size.
  # requires a float argument, that is <tt>(0.0 <= percent <= 100.0)</tt>
  def seek_to_percent(percent)
    return if percent.to_i == @stats[:position]
    percent = percent.to_f
    percent = 0.0   if percent < 0
    percent = 100.0 if percent > 100
    info "SEEK TO: #{percent}%"
    send_command :seek, percent, 1
  end
  
  # seek to an absolute position in a file, by seconds. requires a
  # float between 0.0 and the length (in seconds) of the file being played.
  def seek_to_time(seconds)
    info "SEEK TO: #{seconds} seconds"
    send_command :seek, seconds, 1
  end
  
  # seek by a relative amount, in seconds. requires a float. Negative
  # values rewind to a previous point.
  def seek_by(amount)
    info "SEEK BY: #{amount}"
    send_command :seek, amount, 0
  end
  
  # seek forward a given number of seconds, or
  # <tt>opts[:seek_size]</tt> seconds by default
  def seek_forward(amount = opts[:seek_size])
    seek_by(amount)
  end
  
  # seek backwards (rewind) by a given number of seconds, or
  # <tt>opts[:seek_size]</tt> seconds by default. Note that a
  # /positive/ value here rewinds!
  def seek_reverse(amount = opts[:seek_size])
    seek_by(-amount)
  end
  
  # reset back to the beginning of the file
  def seek_start
    seek_to_percent(0.0)
  end
end
