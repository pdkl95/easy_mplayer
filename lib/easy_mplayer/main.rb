class MPlayer
  attr_accessor :path, :program
  attr_reader   :callbacks, :stats, :child_pid, :worker

  def initialize
    messages :info
    @program   = DEFAULT_MPLAYER_PROGRAM
    @path      = nil
    @stats     = Hash.new
    @callbacks = Hash.new
    @playing   = false
    @worker    = nil
    setup_internal_callbacks!
  end

  def setup_internal_callbacks!
    callback :header_end do
      @mplayer_header = false
    end

    callback :update_position do
      update_stat :raw_position, if @stats[:total_time] == 0.0
                                   0
                                 else
                                   100 * @stats[:played_time] /
                                     @stats[:total_time]
                                 end
      update_stat :position,     @stats[:raw_position].to_i
    end
  end

  # can be any of:
  #   +:quiet+      Supperss all output!
  #   +:error_only+ Off except for errors
  #   +:info+       Also show information messages
  #   +:debug+      Heavy debug output (spammy)
  def messages(type)
    hsh = DEBUG_MESSAGE_TYPES[type.to_sym] or
      raise BadMsgType.new(type.inspect)
    hsh = hsh.dup
    hsh[:debug]       ||= false
    hsh[:info]        ||= false
    hsh[:warn]        ||= false
    hsh[:class_only]  ||= true
    hsh[:prefix_only] ||= false
    ColorDebugMessages.global_debug_flags(hsh)
  end
  
  def inspect # :nodoc:
    vals = [['running', running?],
            ['playing', playing?]]
    vals << ['info', stats.inspect] if running?
    "#<#{self.class} " + vals.map do |x|
      x.first + '=' + x.last.to_s
    end.join(' ') + '>'
  end

  def callbacks(name) # :nodoc:
    @callbacks[name.to_sym] ||= Array.new
  end
  
  # call an entire callback chain, passing in a list of args
  def callback!(name, *args)
    callbacks(name).each do |block|
      #puts "CALLBACK[ #{name.inspect} ] -> (" + args.join(', ') + ')'
      block.call(*args)
    end
  end
  
  # register a function into the named callback chain
  def callback(name, &block)
    callbacks(name).push block
  end

  def ready?
    !!path
  end

  def playing?
    worker and worker.playing?
  end

  def running?
    !!worker
  end
  
  def must_be_ready!
    ready? or raise NotReady
  end
  
  def must_be_running!
    running? or raise NotRunning
  end

  def mplayer_command_line(target = path)
    cmd = "#{program} -slave "
    cmd += "-playlist " if target=~ /\.m3u$/
    cmd += target.to_s
  end

  def find_mplayer_command(name)
    Command.list[name.to_sym]
  end

  def mplayer_cmd!(cmd)
    #must_be_running!
    if worker
      worker.send_command(cmd)
    else
      warn "MPlayer command sent, but the worker is not running!"
      warn "Commmand was: \"#{cmd}\""
    end
  end

  def mplayer_cmd(command, args)
    args = command.validate_args(args)
    mplayer_cmd! [command.cmd, *args].join(' ')
  end

  def send_mplayer_cmd(name, args)
    mplayer_cmd find_mplayer_command(name), args
  end
  
  alias_method :old_method_missing, :method_missing
  def method_missing(sym, *args, &block)
    if command = find_mplayer_command(sym)
      meta_def(command.cmd) do |*cmd_args|
        mplayer_cmd command, cmd_args
      end
      send(sym, *args)
    else
      old_method_missing sym, *args, &block
    end
  end

  def update_stat(name, newval)
    name = name.to_sym
    if @stats[name] != newval
      debug "STATS[:#{name}] -> #{newval.inspect}"
      @stats[name] = newval
      callback! name, newval
    end
  end
  
  def check_line(patterns, line)
    patterns.each_pair do |name, pat|
      if md = pat[:re].match(line)
        args = md.captures.map do |x|
          case x
          when /^\d+$/      then Integer(x)
          when /^\d+\.\d+$/ then Float(x)
          else x
          end
        end
        
        (pat[:stat] || []).each do |field|
          update_stat field, args.shift
        end
        
        callback! name, args
        return name
      end
    end
    nil
  end

  def process_stdout(line)
    if @mplayer_header
      return if check_line(MATCH_HEADER, line)
    end
    return if check_line(MATCH_NORMAL, line)
    #debug "MP> #{line}"
    callback! :stdout, line
  end

  def process_stderr(line)
    callback! :stderr, line
  end

  def process_line(type, line)
    #debug "LINE[ #{type.inspect} ] \"#{line}\""
    case type
    when :stdout then process_stdout(line)
    when :stderr then process_stderr(line)
    else raise MPlayerError, "Unknown stream type #{type.inspect}"
    end
  end

  def play!
    must_be_ready!
    stop if playing?
    
    info "PLAY: #{path}"
    callback! :preparing_mplayer
    @worker = Worker.new(self)
    callback! :playing
  end

  def stop!
    info "STOP!"
    @worker.shutdown! if @worker
    @worker = nil
    callback! :stopped
  end

  def seek_percent(percent)
    return unless running?
    return if percent.to_i == @stats[:position]
    percent = percent.to_f
    percent = 0.0   if percent < 0
    percent = 100.0 if percent > 100
    info "SEEK TO: #{percent}%"
    seek percent, 1
  end
end
