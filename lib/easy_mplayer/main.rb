class MPlayer
  DEFAULT_OPTS = {
    :program       => '/usr/bin/mplayer',
    :message_style => :info,
    :seek_size     => 10
  }
  
  # mplayer is usually in the same place, but change this
  # if your install is strange
  DEFAULT_MPLAYER_PROGRAM = '/usr/bin/mplayer'
  
  # the number of seconds we normally seek by in ff/rw
  DEFAULT_STEP_INCREMENT = 10
  
  # the color_debug_message parameter sets we can switch
  # between, for convenience. (flags for ColorDebugMessages)
  DEBUG_MESSAGE_TYPES = {
    :quiet => {
    },
    :error_only => {
      :warn       => true
    },
    :info => {
      :warn       => true,
      :info       => true
    },
    :debug => {
      :warn       => true,
      :info       => true,
      :debug      => true,
      :class_only => false
    }
  }

  attr_reader   :callbacks, :stats, :opts

  def initialize(new_opts=Hash.new)
    raise "A :path field is required!" unless new_opts[:path]
    raise ":path not a valid file?"    unless File.file?(new_opts[:path])
    @opts = DEFAULT_OPTS.merge(new_opts)
    messages opts[:message_style]
    
    @stats     = Hash.new
    @callbacks = Hash.new
    @worker    = nil

    setup_internal_callbacks!
  end
  
  def setup_internal_callbacks! # :nodoc:
    callback :update_stat do |*args|
      update_stat *args
    end
    
    callback :header_end do
      @mplayer_header = false
    end

    callback :file_error do
      warn "File error!"
      stop!
    end

    callback :played_time do |played_time|
      total = stats[:total_time]
      if total and total != 0.0
        pos = (100 * played_time / total)
        update_stat :raw_position, pos
        update_stat :position,     pos.to_i
      end
    end
    
    callback :startup do
      callback! :play
    end
    
    callback :shutdown do
      @worker = nil
      callback! :stop
    end
  end

  # can be any of:
  #   :quiet      Supperss all output!
  #   :error_only Off except for errors
  #   :info       Also show information messages
  #   :debug      Heavy debug output (spammy)
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
  def callback!(name, *args) # :nodoc:
    #puts "CALLBACK! #{name.inspect} #{args.inspect}"
    callbacks(name).each do |block|
      #puts "CALLBACK[ #{name.inspect} ] -> (" + args.join(', ') + ')'
      block.call(*args)
      #instance_exec *args, &block
    end
  end
  
  # register a function into each of the named callback chains
  def callback(*names, &block)
    names.each do |name|
      callbacks(name).push block
    end
  end
  
  # true if we are running, yet the media has stopped
  def paused?
    @paused
  end

  # true if both mplayer is running and the pause flag is not set
  def playing?
    !@paused and running?
  end
  
  # true if the mplayer process is active and running
  def running?
    !!@worker and @worker.ok?
  end
  
  # pipe a command to mplayer via slave mode
  def send_command(*args)
    worker.send_command(*args)
  end
  
  def worker # :nodoc:
    create_worker if @worker.nil?
    @worker
  end

  def create_worker # :nodoc:
    callback! :creating_worker
    @worker = Worker.new(self)
    @stats  = Hash.new
    @paused = false
    callback! :worker_running
  end
  
  def update_stat(name, newval) # :nodoc:
    name = name.to_sym
    if @stats[name] != newval
      debug "STATS[:#{name}] -> #{newval.inspect}"
      @stats[name] = newval
      callback! name, newval
    end
  end
end
