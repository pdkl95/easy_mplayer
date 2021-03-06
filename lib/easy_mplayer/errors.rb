class MPlayer
  module Error # :nodoc:all
    # all errors thrown form this library will be of this type
    class MPlayerError  < RuntimeError
    end

    class StartupError  < MPlayerError
      attr_reader :path
      
      def to_s
        str = "Missing startup requirement!\n"
        str += "File \"#{path}\" does not exist!\n" unless File.exists?(path)
      end
      
      def initialize(path)
        @path = path
        super(to_s)
      end
    end

    class NoPlayerFound < StartupError
      def to_s
        str = super
        str += "File \"#{path}\" is not executable!\n" unless File.executable?(path)
      end
    end

    class NoTargetPath  < StartupError
      def to_s
        str = super
        str += "file \"#{path}\" is not readable!\n" unless File.readable?(path)
      end
    end

    # some unknown error having to do with the streams/threads that
    # connect us to the mplayer process
    class BadStream    < MPlayerError
    end

    # tried to change to a different level of output that doesn't exist
    class BadMsgType   < MPlayerError
      attr_reader :badtype
      
      def valid_types # :nodoc:
        DEBUG_MESSAGE_TYPES.keys.inspect
      end
      
      def to_s # :nodoc:
        "Bad debug message type \"#{badtype}\"\nValid types " + valid_types
      end
      
      def initialize(type)
        @badtype = type
        super(to_s)
      end
    end
    
    # an error in sending a command to mplayer over its slave-mode API
    class BadCall      < MPlayerError
      attr_reader :cmd, :args

      # a type-prototype of how we attempted the mplayer API call
      def called_as
        "#{cmd}(" + args.map do |x|
          x.class
        end.join(", ") + ")"
      end

      def to_s
        "\nBad MPlayer call: #{called_as}"
      end
      
      def initialize(command, called_args)
        @cmd  = command
        @args = called_args
        super(to_s)
      end
    end

    # tried to pass a slave-mode command to mplayer, but the call didn't
    # match the API prototype mplayer itself provided
    class BadCallArgs  < BadCall
      attr_reader :msg, :usage
      
      def to_s # :nodoc:
        super + " - #{msg}\nusage: #{usage}"
      end
      
      
      def initialize(command, called_args, message)
        @msg   = message
        @usage = command.usage
        super(command.cmd, called_args)
      end
    end
    
    # not a valid command name
    class BadCallName  < BadCall
      def to_s
        super + "\nNo such command \"#{cmd.inspect}\""
      end
    end
  end
  
  include Error
end
