# frozen_string_literal: true

# We use LIKE matching in several places, but for compatibility with Postgres
# and to allow the SQLite code to use indexes for LIKE queries, disable
# SQLite's default case-insensitive LIKE matching

module SQLite3CaseSensitiveLike
  def configure_connection
    super
    execute('PRAGMA case_sensitive_like=ON', 'SCHEMA')
  end
end

ActiveSupport.on_load(:active_record_sqlite3adapter) do
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SQLite3CaseSensitiveLike)
end
