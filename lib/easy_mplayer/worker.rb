class MPlayer
  class Worker # :nodoc:all
    include ColorDebugMessages

    class Stream
      include ColorDebugMessages

      MATCH_STDOUT = { # :nodoc:
        :version => {
          :re   => /^MPlayer\s(\S+)\s\(C\)/,
          :stat => [:version]
        },
        :server => {
          :re   => /^Connecting to server (\S+)\[(\d+\.\d+\.\d+\.\d+)\]:/,
          :stat => [:server, :server_ip]
        },
        :stream_info => {
          :re   => /^ICY Info: StreamTitle='(.*?)';StreamUrl='(.*?)';/,
          :stat => [:stream_title, :stream_url]
        },
        :update_position => {
          :re   => /^A:\s+(\d+\.\d+)\s+\(\S+\)\s+of\s+(\d+\.\d+)/,
          :stat => [:played_time, :total_time],
        },
        :audio_info => {
          :re   => /^AUDIO: (\d+) Hz, (\d+) ch, (\S+), ([0-9.]+) kbit/,
          :stat => [:audio_sample_rate, :audio_channels,
                    :audio_format, :audio_data_rate],
          :call => :audio_stats
        },
        :video_info => {
          :re   => /^VIDEO:\s+\[(\S{4})\]\s+(\d+)x(\d+)\s+(\d+)bpp\s+(\d+\.\d+)\s+fps/,
          :stat => [:video_fourcc, :video_x_size, :video_y_size,
                    :video_bpp, :video_fps],
          :call => :video_stats
        },
        :video_decoder => {
          :re   => /^Opening video decoder: \[(\S+)\]/,
          :stat => [:video_decoder]
        },
        :audio_decoder => {
          :re   => /^Opening audio decoder: \[(\S+)\]/,
          :stat => [:audio_decoder]
        },
        :video_codec => {
          :re   => /^Selected video codec: \[(\S+)\]/,
          :stat => [:video_codec]
        },
        :audio_codec => {
          :re   => /^Selected audio codec: \[(\S+)\]/,
          :stat => [:audio_codec]
        }
      }

      MATCH_STDERR = { # :nodoc:
        :file_not_found => {
          :re => /^File not found: /,
          :call => :file_error
        }
      }
      
      attr_reader :parent, :type, :io
      
      def initialize(p, w, stream_type, stream_io)
        @parent  = p
        @worker  = w
        @type    = stream_type
        @io      = stream_io
        @line    = ''
        @outlist = Array.new
        @stats   = Hash.new
        @select_wait_time = p.opts[:select_wait_time]
        @sent_update_position = false
      end

      def prefix(msg)
        "STREAM [#{@type}] #{msg}"
      end

      def debug(msg); super prefix(msg); end
      def info(msg);  super prefix(msg); end
      def warn(msg);  super prefix(msg); end

      def stream_error(type)
        @worker.flag_stream_error(type)
      end

      def callback!(name, *args)
        case name
        when :update_stat
          stat = args[0]
          val  = args[1]
          if @stats[stat] == val
            return # only propagate changes
          else
            @stats[stat] = val
          end
        end
        @worker.queue_callback [name, args]
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
              callback! :update_stat, field, args.shift
            end
            
            callback! pat[:call] if pat[:call]
            return name
          end
        end
        nil
      end

      def process_stdout(line)
        check_line(MATCH_STDOUT, line)
      end

      def process_stderr(line)
        if check_line(MATCH_STDERR, line)
          stream_error(:stderr)
        end
      end

      def process_line
        # debug "LINE> \"#{@line}\""
        send "process_#{@type}", @line
        # callback! @type, @line
        @line = ''
      end

      def process_stream
        result = IO.select([@io], nil, nil, @select_wait_time)
        return if result.nil? or result.empty?

        c = @io.read(1)
        return stream_error(:eof) if c.nil?
        
        @line << c
        process_line if c == "\n" or c == "\r"
      end

      def run
        @thread = Thread.new do
          @alive = true
          begin
            debug "start"
            process_stream while @alive
            debug "clean end!"
          rescue IOError => e
            if e.to_s =~ /stream closed/
              debug "stream closed!"
            else
              raise BadStream, e.to_s
            end
          rescue => e
            warn "Unexpected error when parsing MPlayer's IO stream!"
            warn "error was: #{e}"
            stream_error(:exception)
          ensure
            cleanup
          end
        end
      end

      def cleanup
        @io.close unless @io.closed?
      end
      
      def kill
        @alive = false
        cleanup
      end

      def join
        @thread.join if @thread
        @thread = nil
      end
    end
    
    attr_reader :parent, :io
    
    def initialize(p)
      @parent  = p
      @pid     = nil
      @streams = Array.new
      @pending = Array.new
      @mutex   = Mutex.new
      @failed  = nil

      @thread_safe_callbacks = @parent.opts[:thread_safe_callbacks]
      @shutdown_in_progress  = false
      
      begin
        info "running mplayer >>> #{cmdline}"
        @io_stdin, @io_stdout, @io_stderr = Open3.popen3(cmdline)
        
        create_stream(:stdout, @io_stdout)
        create_stream(:stderr, @io_stderr)
        send_each_stream :run
      rescue
        raise BadStream, "couldn't create streams to mplayer: #{$!}"
      end
      
      debug "mplayer threads created!"
    end

    def cmdline(target = parent.opts[:path])
      cmd = "#{parent.opts[:program]} -slave "
      cmd += "-playlist " if target=~ /\.m3u$/
      cmd += target.to_s
    end

    def lock!
      @mutex.synchronize do
        yield
      end
    end
    
    def queue_callback(args)
      if @thread_safe_callbacks
        lock! do
          @pending.push(args)
        end
      else
        @parent.callback! args.first, *(args.last)
      end
    end

    def dispatch_callbacks
      return unless @thread_safe_callbacks
      list = nil
      lock! do
        list = @pending
        @pending = Array.new
      end
      list.each do |args|
        @parent.callback! args.first, *(args.last)
      end
    end
    
    def send_to_stdin(str)
      begin
        @io_stdin.puts str
      rescue => e
        warn "Couldn't write to mplayer's stdin!"
        warn "error was: #{e}"
        shutdown!
      end
    end

    def send_command(*args)
      cmd = args.join(' ')
      if @io_stdin.nil?
        debug "cannot send \"#{cmd}\" - stdin closed"
      else
        Command.validate! args
        send_to_stdin cmd
      end
    end

    def create_stream(type, io)
      returning Stream.new(parent, self, type, io) do |stream|
        @streams.push(stream)
      end
    end

    def send_each_stream(*args)
      cmd     = args.shift
      cmd_str = "#{cmd.to_s}(#{args.join(', ')})"
      if @streams.length < 1
        warn "No streams available for \"cmd_str\""
      else
        debug "Sending each stream: #{cmd_str}"
        @streams.each do |stream|
          if stream.respond_to? cmd
            stream.send(cmd, *args)
          else
            raise BadStream, "stream command not valid: #{cmd_str}"
          end
        end
      end
    end

    def flag_stream_error(type)
      lock! do
        @failed = type if @failed.nil?
      end
    end

    def ok?
      dispatch_callbacks
      err = nil
      lock! do
        err = @failed
      end
      return true if err.nil? and @streams.length > 0

      case err
      when :eof
        info "MPlayer process shut itself down!"
        close_stdin
      when :stderr
        warn "Caugh error message on MPlayer's STDERR"
      when :exception
        warn "Unexpected IO stream failure!"
      end
      shutdown!
    end

    def close_stdin
      @io_stdin.close if @io_stdin and !@io_stdin.closed?
      @io_stdin = nil
    end

    def startup!
      @parent.callback! :startup
    end

    def shutdown!
      if @shutdown_in_progress
        debug "shutdown already in progress, skipping shutdown call..."
        return
      end
      
      @parent.callback! :pre_shutdown

      # give mplayer it's close signal
      debug "Sending QUIT to mplayer..."
      @shutdown_in_progress = true
      send_command :quit

      # close our side of the IO
      close_stdin
      
      # then wait for the threads to cleanup after themselves
      info "Waiting for worker thread to exit..."
      send_each_stream :kill
      send_each_stream :join
      @streams = Array.new
      info "MPlayer process cleaned up!"
      @parent.callback! :shutdown
    end
  end
end
