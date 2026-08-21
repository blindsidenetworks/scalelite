# frozen_string_literal: true

module FsapiHelper
  # Escape strings so they are safe to use in freeswitch dialplan XML
  # The problematic string is ${ which introduces a substitution. To prevent the substitution, the $ can be escaped with a
  # backslash (and therefore backslashes also need to be backslash-escaped).
  # Reference the switch_event_expand_headers_check function in freeswitch/src/switch_event.c
  # Due to a quirk of how the freeswitch code checks the string to decide whether it needs to run the string processing
  # which performs unescaping, the $ should not be escaped unless it is followed immediately by {
  # Reference the switch_string_var_check_const and switch_string_has_escaped_data functions in
  # freeswitch/src/include/switch_utils.h (the string unescaping will not run unless one of those functions returns TRUE).
  def fs_escape(val)
    val.gsub(/(\\|\$\{)/, '\\\\\\1')
  end
end
