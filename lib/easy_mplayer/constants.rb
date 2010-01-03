class MPlayer
  DEFAULT_MPLAYER_PROGRAM = '/usr/bin/mplayer'
  
  # the color_debug_message parameter sets we can switch
  # between, for convenience.
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
  
  MATCH_HEADER = {
    :version => {
      :re   => /^MPlayer\s(\S+)\s\(C\) \d+\-\d+/,
      :stat => [:version]
    },
    :server => {
      :re   => /^Connecting to server (\S+)\[(\d+\.\d+\.\d+\.\d+)\]:/,
      :stat => [:server, :server_ip]
    },
    :header_end => {
      :re  => /^Starting playback/
    }
  }

  MATCH_NORMAL = {
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
      :stat => [:sample_rate, :audio_channels, :audio_format, :data_rate]
    }
  }
end
