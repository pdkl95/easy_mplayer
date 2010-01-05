class MPlayer
  class Callback # :nodoc:all
    def initialize(callback_options)
      @block = callback_options[:block]
      @type  = callback_options[:type]
      @scope = callback_options[:scope]
    end
    
    def run!(args)
      unless @block.nil?
        case @type
        when :instance then @block.call(*args)
        when :class    then @scope.instance_exec(*args, &@block)
        end
      end
    end
  end
  
  class CallbackList < Array # :nodoc:all
    attr_reader :name
    
    def initialize(list_name)
      @name = list_name.to_sym
    end

    def register(opts)
      push Callback.new(opts)
    end

    def run!(args)
      each do |x|
        x.run!(args)
      end
    end

    class << self
      def all
        @all ||= Hash.new
      end
      
      def find(name)
        all[name.to_sym] ||= new(name)
      end

      def register(opts)
        find(opts[:name]).register(opts)
      end

      def run!(name, args)
        find(name).run!(args)
      end
    end
  end
end
