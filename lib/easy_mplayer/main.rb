class MPlayer
  # all of these can be overridden by passing them to #new
  DEFAULT_OPTS = {
    :program               => '/usr/bin/mplayer',
    :message_style         => :info,
    :seek_size             => 10,
    :thread_safe_callbacks => true
  }
  
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

  attr_reader :callbacks, :stats, :opts

  class << self
    def class_callbacks # :nodoc:
      @@class_callbacks ||= Array.new
    end
    
    # register a block with the named callback(s). This is the same
    # as the instance-method, generally, but it uses instance_exec to
    # give the block the same scope (the MPlayer instance)
    def callback(*names, &block)
      names.each do |name|
        class_callbacks << {
          :name  => name,
          :type  => :class,
          :block => block
        }
      end
    end
  end
  
  # create a new object, with the named options
  # valid options:
  #     :program               Path to the mplayer binary itself
  #                            (default: /usr/bin/mplayer)
  #     :path                  Path to the media file to be played
  #     :message_style         How verbose our debug messages should
  #                            be (see #set_message_style)
  #     :seek_size             Time, in seconds, to seek
  #                            forwards/reverse by default (default:
  #                            10 seconds)
  #     :thread_safe_callbacks If we should buffer callbacks back to
  #                            the main thread, so they are called off
  #                            the #playing? polling-loop (default: true)
  def initialize(new_opts=Hash.new)
    @opts = DEFAULT_OPTS.merge(new_opts)
    set_message_style opts[:message_style]
    
    unless File.executable?(@opts[:program])
      raise NoPlayerFound.new(@opts[:program]) 
    end
    
    @stats     = Hash.new
    @callbacks = Hash.new
    @worker    = nil

    self.class.class_callbacks.each do |opts|
      opts[:scope] = self
      CallbackList.register opts
    end
  end

  callback :update_stat do |*args|
    update_stat *args
  end

  callback :file_error do
    warn "File error!"
    stop
  end

  callback :startup do
    callback! :play
  end
  
  callback :shutdown do
    @worker = nil
    callback! :stop
  end
  
  # true if we can call #play without an exception
  def ready?
    @opts[:path] and File.readable?(@opts[:path])
  end
  
  def must_be_ready! # :nodoc:
    ready? or raise NoTargetPath.new(@opts[:path])
  end
  
  # returns the path we are currently playing
  def path
    @opts[:path]
  end
  
  # sets the path to #play - this does not interrupt a currently
  # playing file. #stop and #play should be called again.
  def path=(val)
    @opts[:path] = val
  end
  
  # takes a block, that should return the X11 window_id of a window
  # that mplayer can use as a render target. This will cause mplayer
  # to embed its output into that window, as if it was a native widget.
  def embed(&block)
    @opts[:embed] = block
  end

  # can be any of:
  #   :quiet      Supperss all output!
  #   :error_only Off except for errors
  #   :info       Also show information messages
  #   :debug      Heavy debug output (spammy)
  def set_message_style(type)
    hsh = DEBUG_MESSAGE_TYPES[type.to_sym] or
      raise BadMsgType.new(type.inspect)
    hsh = hsh.dup
    hsh[:debug]       ||= false
    hsh[:info]        ||= false
    hsh[:warn]        ||= false
    hsh[:class_only]  ||= true
    hsh[:prefix_only] ||= false
    ColorDebugMessages.global_debug_flags(hsh)
    opts[:message_style] = type
  end
  
  def inspect # :nodoc:
    vals = [['running', running?],
            ['paused',  paused?]]
    vals << ['info', stats.inspect] if running?
    "#<#{self.class} " + vals.map do |x|
      x.first + '=' + x.last.to_s
    end.join(' ') + '>'
  end

  # call an entire callback chain, passing in a list of args
  def callback!(name, *args) # :nodoc:
    #puts "CALLBACK! #{name.inspect} #{args.inspect}"
    CallbackList.run!(name, args)
  end
  
  # register a function into each of the named callback chains
  def callback(*names, &block)
    names.each do |name|
      CallbackList.register :name => name, :block => block, :type => :instance
    end
  end
  
  # true if we are running, yet the media has stopped
  def paused?
    @paused
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
      debug "STATS[:#{name}] #{@stats[name].inspect} -> #{newval.inspect}"
      @stats[name] = newval
      callback! name, newval
    end
  end
end
