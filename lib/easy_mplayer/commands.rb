class MPlayer
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
end
