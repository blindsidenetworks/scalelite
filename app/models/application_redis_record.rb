# frozen_string_literal: true

class ApplicationRedisRecord
  include ActiveModel::Model
  include ActiveModel::AttributeMethods
  include ActiveModel::Dirty
  include ActiveModel::Naming

  class ApplicationRedisError < StandardError
  end

  # Raised by find helper methods when they didn't find anything
  class RecordNotFound < ApplicationRedisError
    attr_reader :model, :id

    def initialize(message = nil, model = nil, id = nil)
      @model = model
      @id = id

      super(message)
    end
  end

  # Raised by the create! and save! methods when the object is invalid and cannot be saved
  class RecordNotSaved < ApplicationRedisError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end

  # Raised by the destroy! method when something prevents the object from being destroyed
  class RecordNotDestroyed < ApplicationRedisError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end

  # Raised by the create!, save!, and destroy! methods when the modification was aborted
  # because of a conflicting concurrent modification. The change should be retried.
  class ConcurrentModificationError < ApplicationRedisError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end

  # Initialize a new object. You can optionally pass a hash of attributes to assign.
  def initialize(attributes = {})
    super(attributes)
    @new_record = true
    @destroyed = false
  end

  # Initialize a new object, and attempt to save it immediately. Raises a RecordNotSaved exception on errors, otherwise returns
  # the newly created object.
  def self.create!(attributes = {})
    object = new(attributes)
    object.save!
  end

  # Initialize a new object, and attempt to save it immediately. Returns the newly created object. If it was not successfully
  # saved, the persisted? method on the new object will return false.
  def self.create(attributes = {})
    create!(attributes)
  rescue RecordNotSaved => e
    e.record
  end

  # Save the object. Raises a RecordNotSaved exception on errors. Returns the object.
  # This method has to be implemented by subclasses, which should first persist the data, then call super so we can do some
  # bookkeeping here
  def save!
    changes_applied
    @new_record = false
    self
  end

  # Save the object. Returns true if it was successfully saved, or false otherwise.
  def save
    save!
    true
  rescue RecordNotSaved
    false
  end

  # Destroy the object. Raises a RecordNotSaved exception on errors. Returns the object.
  # This method has to be implemented by subclasses, which should first destroy the data, then call super so we can do some
  # bookkeeping here
  def destroy!
    @destroyed = true
    self
  end

  # Destroy the object. Returns true if it was successfully destroyed, or false otherwise.
  def destroy
    destroy!
    true
  rescue RecordNotDestroyed
    false
  end

  # Check if the object exists in the backend data store
  def persisted?
    !@new_record && !@destroyed
  end

  # Internal initialization helper for loading from store
  def init_with_attributes(attributes, new_record = false)
    self.attributes = attributes
    clear_changes_information
    @new_record = new_record
    self
  end

  def self.application_redis_attr(*syms)
    attr_reader(*syms)
    syms.each do |sym|
      raise NameError, "invalid attribute name: #{sym}" unless /^[_A-Za-z]\w*$/.match?(sym)

      class_eval(<<-END_OF_RUBY, __FILE__, __LINE__ + 1)
        def #{sym}=(value)
          #{sym}_will_change! unless @#{sym} == value
          @#{sym} = value
        end
      END_OF_RUBY
    end
  end

  def self.connection_pool
    RedisStore.connection_pool
  end
  delegate :connection_pool, to: 'self.class'

  def self.with_connection
    RedisStore.with_connection do |redis|
      yield(redis)
    end
  end
  delegate :with_connection, to: 'self.class'

  def self.logger
    Rails.logger
  end
  delegate :logger, to: 'self.class'
end
