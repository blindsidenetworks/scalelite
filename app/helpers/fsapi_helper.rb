# frozen_string_literal: true

module FsapiHelper
  # Escape strings so they are safe to use in freeswitch dialplan XML
  # The problematic character is $ which introduces a substitution. It can be escaped with a backslash, which means that
  # plain backslash also needs to be escaped.
  # Reference the switch_event_expand_headers_check function in freeswitch/src/switch_event.c
  def fs_escape(val)
    val.to_s.gsub(/([\\$])/, '\\\\\\1')
  end
end
