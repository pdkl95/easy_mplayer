class MPlayer
  def play_to_end
    play
    sleep 1 while running?
  end
  
  def play
    stop if playing?
    
    info "PLAY: #{opts[:path]}"
    worker.startup!
  end

  def stop
    info "STOP!"
    @worker.shutdown! if @worker
  end

  def pause
    return if paused?
    info "PAUSE!"
    send_command :pause
    @paused = true
    callback! :pause
  end

  def unpause
    return unless paused?
    info "UNPAUSE!"
    send_command :pause
    @paused = false
    callback! :unpause
  end

  def pause_or_unpause
    paused? ? unpause : pause
  end

  def seek_to_percent(percent)
    return if percent.to_i == @stats[:position]
    percent = percent.to_f
    percent = 0.0   if percent < 0
    percent = 100.0 if percent > 100
    info "SEEK TO: #{percent}%"
    send_command :seek, percent, 1
  end

  def seek_to_time(seconds)
    info "SEEK TO: #{seconds} seconds"
    send_command :seek, seconds, 1
  end

  def seek_by(amount)
    info "SEEK BY: #{amount}"
    send_command :seek, amount, 0
  end

  def seek_forward(amount = opts[:seek_size])
    seek_by(amount)
  end

  def seek_reverse(amount = opts[:seek_size])
    seek_by(-amount)
  end

  def seek_start
    seek_to_percent(0.0)
  end
end
