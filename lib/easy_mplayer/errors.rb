class MPlayer
  # all errors thrown form this library will be of this type
  class MPlayerError < RuntimeError
  end

  # tried to start mplayer, but we were not ready yet (no file selected?)
  class NotReady     < MPlayerError
  end

  # tried to send a command to mplayer, but it was not running
  class NotRunning   < MPlayerError
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

  # tried to pass a slave-mode command to mplayer, but the call didn't
  # match the API prototype mplayer itself provided
  class BadCall      < MPlayerError
    attr_reader :cmd, :given_args, :msg

    # a type-prototype of how we attempted the mplayer API call
    def called_as
      "#{cmd.cmd}(" + given_args.map do |x|
        x.class
      end.join(", ") + ")"
    end

    def error_msg # :nodoc:
      "#{called_as} - #{msg}"
    end

    def to_s # :nodoc:
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
end
