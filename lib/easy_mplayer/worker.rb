class MPlayer
  class Worker
    include ColorDebugMessages

    class Stream
      include ColorDebugMessages
      attr_reader :parent, :type, :io
      
      def initialize(p, stream_type, stream_io)
        @parent = p
        @type = stream_type
        @io   = stream_io
        @line = ''
        @outlist = Array.new
        @mutex   = Mutex.new
      end

      def name
        "STREAM [#{@type}]"
      end

      def prefix(msg)
        "#{name} #{msg}"
      end

      def debug(msg); super prefix(msg); end
      def info(msg);  super prefix(msg); end
      def warn(msg);  super prefix(msg); end

      def process_line
        @parent.process_line(@type, @line.chomp)
        @line = ''
      end

      def process_stream
        c = if IO.select([@io], nil, nil, 100).empty?
              nil
            else
              @io.read(1)
            end
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
    
    attr_reader :parent, :cmdline, :io
    
    def initialize(p)
      @parent  = p
      @pid     = nil
      @cmdline = parent.mplayer_command_line
      @streams = Array.new
      
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

    def playing?
      @streams.length > 0
    end

    def send_command(cmd)
      debug "MPLAYER_CMD: #{cmd.inspect}"
      @io_stdin.puts cmd
    end

    def create_stream(type, io)
      returning Stream.new(parent, type, io) do |stream|
        @streams.push(stream)
      end
    end

    def send_each_stream(*args)
      cmd     = args.shift
      cmd_str = "#{cmd.to_s}(#{args.join(', ')})"
      if @streams.length < 1
        warn "No streams available for \"cmd_str\""
      else
        info "Sending each stream: #{cmd_str}"
        @streams.each do |stream|
          if stream.respond_to? cmd
            stream.send(cmd, *args)
          else
            raise BadStream, "stream command not valid: #{cmd_str}"
          end
        end
      end
    end

    def shutdown!
      # give mplayer it's close signal
      debug "Sending QUIT to mplayer..."
      send_command "quit"

      # close our side of the IO
      @io_stdin.close

      # then wait for the threads to cleanup after themselves
      info "Waiting for worker thread to exit..."
      send_each_stream :kill
      send_each_stream :join
      @streams = Array.new
      debug "MPlayer process cleanly shutdown!"
    end
  end
end
