require 'fl/framework'

# The base access control algorithms for testing the framework are set up as follows:
# - the BaseAsset, OverrideAsset, ExtendAsset, and InlineAsset classes define objects that are placed under AC
# - the NoAccessAsset class define objects that do not support AC
# - the User class defines the actors
# - Asset classes have an integer "code" value and a string "name" value
# - User has an integer "key" value
# - BaseAsset :a grants permissions to User :u as follows:
#   - for :index : granted if u.key > 100
#   - for :create : granted if u.key > 140
#   - for :read : granted if u.key > a.code
#   - for :write : granted if u.key > a.code, and u.key is even
#   - for :destroy : never granted
# - the OverrideAsset class overrides :index and :read behavior
#   - for :index : granted if u.key is odd
#   - for :write : granted if u.key > 120
# - the ExtendAsset class adds two operations:
#   - ExtendAccess::CLASS_OP is a class scope operation
#     granted if u.key > 100
#   - ExtendAccess::INSTANCE_OP is an instance scope operation
#     granted if u.key > a.code, and u.key is odd
# - the InlineAsset class has the same access algorithms as BaseAsset, but they are embedded in the class
#   directly, rather than through a mixin

# In addition, the various classes also implement the model hash package, so that they can be used
# for model hash testing. We need access support so that we can test permission hashing.
# We also define the NoAccessAsset class, which does not implement the access package.

module BaseAccess
  module ClassMethods
    def default_access_checker(op, obj, actor, context = nil)
      case op.op
      when Fl::Framework::Access::Grants::INDEX
        (actor.key > 100) ? :ok : nil
      when Fl::Framework::Access::Grants::CREATE
        (actor.key > 140) ? :ok : nil
      when Fl::Framework::Access::Grants::READ
        (actor.key > obj.code) ? :ok : nil
      when Fl::Framework::Access::Grants::WRITE
        ((actor.key > obj.code) && ((actor.key % 2) == 0)) ? :ok : nil
      else
        nil
      end
    end
  end

  module InstanceMethods
  end

  def self.included(base)
    base.extend ClassMethods

    base.instance_eval do
    end

    base.class_eval do
      include InstanceMethods
    end
  end
end

class BaseAsset
  include Fl::Framework::Access::Access
  include BaseAccess
  include Fl::Framework::Core::ModelHash

  def initialize(name, code)
    @name = name
    @code = code
    @id = rand(100)
  end

  def id()
    return @id
  end

  def name()
    @name
  end

  def code()
    @code
  end

  protected

  def to_hash_options_for_verbosity(actor, verbosity, opts)
    case verbosity
    when :id, :ignore
      {}
    when :minimal
      {
        :include => [ :code ]
      }
    when :standard, :verbose, :complete
      {
        :include => [ :code, :name ]
      }
    else
      {}
    end
  end

  def to_hash_local(actor, keys, opts = {})
    to_hash_opts = opts[:to_hash] || {}

    rv = {
    }
    keys.each do |k|
      sk = k.to_sym
      case sk
      when :name
        # could let it go below, but just for fun we treat it separately

        rv[sk] = self.name
      else
        rv[sk] = self.send(k) if self.respond_to?(k)
      end
    end

    rv
  end
end

class InlineAsset
  include Fl::Framework::Access::Access
  include Fl::Framework::Core::ModelHash

  def initialize(name, code)
    @name = name
    @code = code
    @id = rand(100)
  end

  def id()
    return @id
  end

  def name()
    @name
  end

  def code()
    @code
  end

  def self.default_access_checker(op, obj, actor, context = nil)
    case op.op
    when Fl::Framework::Access::Grants::INDEX
      (actor.key > 100) ? :ok : nil
    when Fl::Framework::Access::Grants::CREATE
      (actor.key > 140) ? :ok : nil
    when Fl::Framework::Access::Grants::READ
      (actor.key > obj.code) ? :ok : nil
    when Fl::Framework::Access::Grants::WRITE
      ((actor.key > obj.code) && ((actor.key % 2) == 0)) ? :ok : nil
    else
      nil
    end
  end

  protected

  def to_hash_options_for_verbosity(actor, verbosity, opts)
    case verbosity
    when :id, :ignore
      {}
    when :minimal
      {
        :include => [ :code ]
      }
    when :standard, :verbose, :complete
      {
        :include => [ :code, :name ]
      }
    else
      {}
    end
  end

  def to_hash_local(actor, keys, opts = {})
    to_hash_opts = opts[:to_hash] || {}

    rv = {
    }
    keys.each do |k|
      sk = k.to_sym
      case sk
      when :name
        # could let it go below, but just for fun we treat it separately

        rv[sk] = self.name
      else
        rv[sk] = self.send(k) if self.respond_to?(k)
      end
    end

    rv
  end
end

class OverrideAsset
  include Fl::Framework::Access::Access
  include BaseAccess
  include Fl::Framework::Core::ModelHash
  
  access_op :index, :my_index_check
  access_op :write, :my_write_check

  def initialize(name, code)
    @name = name
    @code = code
  end

  def name()
    @name
  end

  def code()
    @code
  end

  protected

  def to_hash_options_for_verbosity(actor, verbosity, opts)
    case verbosity
    when :id, :ignore
      {}
    when :minimal
      {
        :include => [ :code ]
      }
    when :standard, :verbose, :complete
      {
        :include => [ :code, :name ]
      }
    else
      {}
    end
  end

  def to_hash_local(actor, keys, opts = {})
    to_hash_opts = opts[:to_hash] || {}

    rv = {
    }
    keys.each do |k|
      sk = k.to_sym
      case sk
      when :name
        # could let it go below, but just for fun we treat it separately

        rv[sk] = self.name
      else
        rv[sk] = self.send(k) if self.respond_to?(k)
      end
    end

    rv
  end

  private

  def self.my_index_check(op, obj, actor, context = nil)
    ((actor.key % 2) == 0) ? nil : :ok
  end

  def my_write_check(op, obj, actor, context = nil)
    (actor.key > 120) ? :ok : nil
  end
end

# ExtendAccess adds its own operation
# - for :class_op : granted if u.key > 100
# - for :instance_op : granted if u.key > a.code, and u.key is odd

module ExtendAccess
  CLASS_OP = :class_op
  INSTANCE_OP = :instance_op

  module ClassMethods
    def default_access_checker(op, obj, actor, context = nil)
      case op.op
      when Fl::Framework::Access::Grants::INDEX
        (actor.key > 100) ? :ok : nil
      when Fl::Framework::Access::Grants::CREATE
        (actor.key > 140) ? :ok : nil
      when Fl::Framework::Access::Grants::READ
        (actor.key > obj.code) ? :ok : nil
      when Fl::Framework::Access::Grants::WRITE
        ((actor.key > obj.code) && ((actor.key % 2) == 0)) ? :ok : nil
      when CLASS_OP
        (actor.key > 100) ? :ok : nil
      when INSTANCE_OP
        ((actor.key > obj.code) && ((actor.key % 2) != 0)) ? :ok : nil
      else
        nil
      end
    end
  end

  module InstanceMethods
  end

  def self.included(base)
    base.extend ClassMethods

    base.instance_eval do
    end

    base.class_eval do
      include InstanceMethods

      access_op(ExtendAccess::CLASS_OP, :default_access_checker, { context: :class })
      access_op(ExtendAccess::INSTANCE_OP, :default_access_checker, { context: :instance })
    end
  end
end

class ExtendAsset
  include Fl::Framework::Access::Access
  include ExtendAccess
  include Fl::Framework::Core::ModelHash

  def initialize(name, code)
    @name = name
    @code = code
  end

  def name()
    @name
  end

  def code()
    @code
  end

  protected

  def to_hash_operations_list()
    super() | [ ExtendAccess::INSTANCE_OP ]
  end

  def to_hash_options_for_verbosity(actor, verbosity, opts)
    case verbosity
    when :id, :ignore
      {}
    when :minimal
      {
        :include => [ :code ]
      }
    when :standard, :verbose, :complete
      {
        :include => [ :code, :name ]
      }
    else
      {}
    end
  end

  def to_hash_local(actor, keys, opts = {})
    to_hash_opts = opts[:to_hash] || {}

    rv = {
    }
    keys.each do |k|
      sk = k.to_sym
      case sk
      when :name
        # could let it go below, but just for fun we treat it separately

        rv[sk] = self.name
      else
        rv[sk] = self.send(k) if self.respond_to?(k)
      end
    end

    rv
  end
end

class NoAccessAsset
  include Fl::Framework::Core::ModelHash

  def initialize(name, code)
    @name = name
    @code = code
    @id = rand(100)
  end

  def id()
    return @id
  end

  def name()
    @name
  end

  def code()
    @code
  end

  protected

  def to_hash_options_for_verbosity(actor, verbosity, opts)
    case verbosity
    when :id, :ignore
      {}
    when :minimal
      {
        :include => [ :code ]
      }
    when :standard, :verbose, :complete
      {
        :include => [ :code, :name ]
      }
    else
      {}
    end
  end

  def to_hash_local(actor, keys, opts = {})
    to_hash_opts = opts[:to_hash] || {}

    rv = {
    }
    keys.each do |k|
      sk = k.to_sym
      case sk
      when :name
        # could let it go below, but just for fun we treat it separately

        rv[sk] = self.name
      else
        rv[sk] = self.send(k) if self.respond_to?(k)
      end
    end

    rv
  end
end

class User
  def initialize(name, key)
    @name = name
    @key = key
  end

  def name()
    @name
  end

  def key()
    @key
  end
end
