require 'color_debug_messages'
require 'open3'
require 'facets/kernel/returning'
require 'facets/kernel/instance_exec'
require 'facets/kernel/meta_class'
require 'facets/kernel/meta_def'

class MPlayer
  include ColorDebugMessages
end

require 'easy_mplayer/errors'
require 'easy_mplayer/commands'
require 'easy_mplayer/worker'
require 'easy_mplayer/main'
require 'easy_mplayer/helpers'

