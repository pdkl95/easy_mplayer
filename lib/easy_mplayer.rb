require 'color_debug_messages'
require 'open3'
require 'facets/kernel/returning'
require 'facets/kernel/meta_class'
require 'facets/kernel/meta_def'

class IO
  def next_mplayer_line(stream_id=nil)
    @str ||= ''
    begin
      while c = self.getc
        @str << c
        if c < 0x10
          ret = @str.chomp
          @str = ''
          return ret
        end
      end
    rescue
      if $!.to_s != 'stream closed'
        if stream_id
          $stderr.puts "io_stream[#{stream_id}]>> " + $!.to_s
        else
          $stderr.puts "io_stream>> " + $!.to_s
        end
      end
    end
    nil
  end
end

class MPlayer
  include ColorDebugMessages
  
  class MPlayerError < RuntimeError; end
  class NotReady     < MPlayerError; end
  class NotRunning   < MPlayerError; end
  class BadCall      < MPlayerError
    attr_reader :cmd, :given_args, :msg
    
    def called_as
      "#{cmd.cmd}(" + given_args.map do |x|
        x.class
      end.join(", ") + ")"
    end

    def error_msg
      "#{called_as} - #{msg}"
    end

    def to_s
      ["Bad MPlayer call!",
       "error: " + error_msg,
       "usage: " + cmd.usage
      ].join("\n")
    end
    
    def initialize(command, called_args, message)
      @cmd        = command
      @given_args = called_args
      @msg        = message
      super(to_s)
    end
  end

  class Command
    class << self
      def cmdlist_raw
        @cmdlist_raw ||= `mplayer -input cmdlist`.split(/\n/)
      end

      def list
        @list ||= returning Hash.new do |hsh|
          cmdlist_raw.map do |line|
            cmd, *opts = line.split(/\s+/)
            hsh[cmd.to_sym] = new(cmd, opts)
          end
        end
      end
    end

    attr_reader :cmd, :names, :opts, :max, :min

    def initialize(command_name, opt_list)
      @cmd   = command_name
      @min   = 0
      @max   = opt_list.length
      @names = opt_list
      @opts  = opt_list.map do |opt|
        @min += 1 if opt[0,1] != '['
        case opt
        when 'Integer', '[Integer]' then :int
        when 'Float',   '[Float]'   then :float
        when 'String',  '[String]'  then :string
        else raise "Unknown cmd option type: #{opt}"
        end
      end
    end

    def usage
      "#{cmd}(" + names.join(", ") + ")"
    end

    def to_s
      usage
    end

    def inspect
      "#<#{self.class} \"#{usage}\">"
    end

    def convert_arg_type(val, type)
      begin
        case type
        when :int    then Integer(val)
        when :float  then Float(val)
        when :string then val.to_s
        end
      rescue
        nil
      end
    end

    def validate_args(args)
      len = args.length
      raise BadCall.new(self, args, "not enough args") if len < min
      raise BadCall.new(self, args, "too many args")   if len > max
      returning Array.new do |new_args|
        args.each_with_index do |x,i|
          new_args.push convert_arg_type(x, opts[i]) or
            raise BadCall.new(self, args, "type mismatch")
        end
      end
    end
  end
  
  attr_accessor :path
  attr_reader   :child_pid
  
  def initialize(target_path = nil)
    @playing   = false
    @child_pid = nil
    @worker    = nil
    @path      = target_path
    @info      = Hash.new
    @callback  = Hash.new

    callback :header_end do
      @mplayer_header = false
    end

    callback :update_position do
      update_info :raw_position, if @info[:total_time] == 0.0
                                   0
                                 else
                                   100 * @info[:played_time] /
                                     @info[:total_time]
                                 end
      update_info :position,     @info[:raw_position].to_i
    end
  end

  def inspect
    vals = [['running', running?],
            ['playing', playing?]]
    vals << ['info', info.inspect] if running?
    "#<#{self.class} " + vals.map do |x|
      x.first + '=' + x.last.to_s
    end.join(' ') + '>'
  end

  def callbacks(name)
    @callback[name.to_sym] ||= Array.new
  end

  def callback!(name, *args)
    callbacks(name).each do |block|
      #puts "CALLBACK[ #{name.inspect} ] -> (" + args.join(', ') + ')'
      block.call(*args)
    end
  end

  def callback(name, &block)
    callbacks(name).push block
  end
  
  def ready?
    !!@path
  end

  def playing?
    !!@playing
  end

  def running?
    !!@mplayer_io
  end
  
  def must_be_ready!
    ready? or raise NotReady
  end
  
  def must_be_running!
    running? or raise NotRunning
  end

  def mplayer_command_line(target = @path)
    cmd = "/usr/bin/mplayer -slave "
    cmd += "-playlist " if target=~ /\.m3u$/
    cmd += target.to_s
  end

  def each_output_line(stream_id)
    Thread.new do
      while @playing
        line = @mplayer_io[stream_id].next_mplayer_line stream_id 
        yield line if line
      end
    end
  end

  def start_mplayer_process!
    stdin, stdout, stderr = Open3.popen3 mplayer_command_line
    @mplayer_io = {
      :in  => stdin,
      :out => stdout,
      :err => stderr
    }
    @playing = true
    @mplayer_header = true
  end

  def find_mplayer_command(name)
    Command.list[name.to_sym]
  end

  def mplayer_cmd!(cmd)
    info "MPLAYER_CMD: #{cmd.inspect}"
    must_be_running!
    @mplayer_io[:in].puts cmd
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

  def stop_mplayer_process!
    @playing = false
    quit
  end

  MATCH_HEADER = {
    :version => {
      :re   => /^MPlayer\s(\S+)\s\(C\) \d+\-\d+/,
      :info => [:version]
    },
    :server => {
      :re   => /^Connecting to server (\S+)\[(\d+\.\d+\.\d+\.\d+)\]:/,
      :info => [:server, :server_ip]
    },
    :header_end => {
      :re  => /^Starting playback/
    }
  }

  MATCH_NORMAL = {
    :stream_info => {
      :re   => /^ICY Info: StreamTitle='(.*?)';StreamUrl='(.*?)';/,
      :info => [:stream_title, :stream_url]
    },
    :update_position => {
      :re   => /^A:\s+(\d+\.\d+)\s+\(\S+\)\s+of\s+(\d+\.\d+)/,
      :info => [:played_time, :total_time],
    },
    :audio_info => {
      :re   => /^AUDIO: (\d+) Hz, (\d+) ch, (\S+), ([0-9.]+) kbit/,
      :info => [:sample_rate, :audio_channels, :audio_format, :data_rate]
    }
  }

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
        
        (pat[:info] || []).each do |field|
          update_info field, args.shift
        end
        
        callback! name, args
        return name
      end
    end
    nil
  end

  def mplayer_stdout(line)
    if @mplayer_header
      return if check_line(MATCH_HEADER, line)
    end
    return if check_line(MATCH_NORMAL, line)
    debug "MP> #{line}"
    callback! :stdout, line
  end

  def mplayer_stderr(line)
    callback! :stderr, line
  end

  def play!
    must_be_ready!
    quit if playing?
    
    info "PLAY: #{@path}"
    callback! :preparing_mplayer
    
    @worker = Thread.new do
      info "mplayer command >>> #{mplayer_command_line}"
      begin
        start_mplayer_process!
        
        @stdout_worker = each_output_line(:out) do |out|
          mplayer_stdout out
        end
        @stderr_worker = each_output_line(:err) do |err|
          mplayer_stderr err
        end
        
      rescue
        warn "mplayer error: #{$!}"
        @playing = false
      ensure
        @stdout_worker.join
        @stderr_worker.join        
      end
      info "mplayer monitor process finished!"
    end

    callback! :playing
  end

  def quit(*args)
    @playing = false
    send_mplayer_cmd :quit, args
    info "Waiting for worker thread to exit..."
    @worker.join if @worker
    @worker = nil
    callback! :quit
  end

  def stop!
    quit if playing?
    info "mplayer stopped!"
    callback! :stopped
  end

  def seek_percent(percent)
    return unless running?
    return if percent.to_i == @info[:position]
    percent = percent.to_f
    percent = 0.0   if percent < 0
    percent = 100.0 if percent > 100
    seek percent, 1
  end

  def update_info(name, newval)
    name = name.to_sym
    if @info[name] != newval
      debug "INFO[ #{name.inspect} ] -> #{newval}"
      @info[name] = newval
      callback! name, newval
    end
  end

  def upxdate_position(args)
  end
end
