require 'minitest/autorun'
require 'fl/framework'

# The base access control algorithms for testing the framework are set up as follows:
# - the BaseAsset class defines objects that are placed under AC
# - the User class defines the actors
# - BaseAsset has an integer "code" value
# - User has an integer "key" value
# - BaseAsset :a grants permissions to User :u as follows:
#   - for :index : granted if u.key > 100
#   - for :create : granted if u.key > 140
#   - for :read : granted if u.key > a.code
#   - for :write : granted if u.key > a.code, and u.key is even
# - the OverrideAsset class overrides :index and :read behavior
#   - for :index : granted if u.key is odd
#   - for :write : granted if u.key > 120

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
end

class OverrideAsset
  include Fl::Framework::Access::Access
  include BaseAccess
  
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
  
class BaseTest < Minitest::Test
  def test_base_access
    u1_50 = User.new('u1_50', 50)
    u2_120 = User.new('u2_120', 120)
    u3_145 = User.new('u3_145', 145)

    a1_10 = BaseAsset.new('a1_10', 10)
    a2_80 = BaseAsset.new('a2_80', 80)
    a3_110 = BaseAsset.new('a3_110', 110)
    a4_200 = BaseAsset.new('a4_200', 200)

    assert_nil BaseAsset.permission?(u1_50, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, BaseAsset.permission?(u2_120, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, BaseAsset.permission?(u3_145, Fl::Framework::Access::Grants::INDEX)

    assert_nil BaseAsset.permission?(u1_50, Fl::Framework::Access::Grants::CREATE)
    assert_nil BaseAsset.permission?(u2_120, Fl::Framework::Access::Grants::CREATE)
    assert_equal :ok, BaseAsset.permission?(u3_145, Fl::Framework::Access::Grants::CREATE)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a1_10.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a2_80.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a3_110.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)
  end

  def test_override_access
    u1_50 = User.new('u1_50', 50)
    u2_120 = User.new('u2_120', 120)
    u3_145 = User.new('u3_145', 145)

    a1_10 = OverrideAsset.new('a1_10', 10)
    a2_80 = OverrideAsset.new('a2_80', 80)
    a3_110 = OverrideAsset.new('a3_110', 110)
    a4_200 = OverrideAsset.new('a4_200', 200)

    assert_nil OverrideAsset.permission?(u1_50, Fl::Framework::Access::Grants::INDEX)
    assert_nil OverrideAsset.permission?(u2_120, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, OverrideAsset.permission?(u3_145, Fl::Framework::Access::Grants::INDEX)

    assert_nil OverrideAsset.permission?(u1_50, Fl::Framework::Access::Grants::CREATE)
    assert_nil OverrideAsset.permission?(u2_120, Fl::Framework::Access::Grants::CREATE)
    assert_equal :ok, OverrideAsset.permission?(u3_145, Fl::Framework::Access::Grants::CREATE)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a1_10.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a1_10.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a1_10.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a2_80.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a2_80.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a3_110.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a3_110.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a4_200.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)
  end

  def test_extend_access
    u1_50 = User.new('u1_50', 50)
    u2_120 = User.new('u2_120', 120)
    u3_145 = User.new('u3_145', 145)

    a1_10 = ExtendAsset.new('a1_10', 10)
    a2_80 = ExtendAsset.new('a2_80', 80)
    a3_110 = ExtendAsset.new('a3_110', 110)
    a4_200 = ExtendAsset.new('a4_200', 200)

    assert_nil ExtendAsset.permission?(u1_50, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, ExtendAsset.permission?(u2_120, Fl::Framework::Access::Grants::INDEX)
    assert_equal :ok, ExtendAsset.permission?(u3_145, Fl::Framework::Access::Grants::INDEX)

    assert_nil ExtendAsset.permission?(u1_50, Fl::Framework::Access::Grants::CREATE)
    assert_nil ExtendAsset.permission?(u2_120, Fl::Framework::Access::Grants::CREATE)
    assert_equal :ok, ExtendAsset.permission?(u3_145, Fl::Framework::Access::Grants::CREATE)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a1_10.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a2_80.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_equal :ok, a3_110.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::READ)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::READ)

    assert_equal :ok, a1_10.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a1_10.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a1_10.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a2_80.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a2_80.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a2_80.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a3_110.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_equal :ok, a3_110.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a3_110.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil a4_200.permission?(u1_50, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u2_120, Fl::Framework::Access::Grants::WRITE)
    assert_nil a4_200.permission?(u3_145, Fl::Framework::Access::Grants::WRITE)

    assert_nil ExtendAsset.permission?(u1_50, ExtendAccess::CLASS_OP)
    assert_equal :ok, ExtendAsset.permission?(u2_120, ExtendAccess::CLASS_OP)
    assert_equal :ok, ExtendAsset.permission?(u3_145, ExtendAccess::CLASS_OP)

    assert_nil a1_10.permission?(u1_50, ExtendAccess::INSTANCE_OP)
    assert_nil a1_10.permission?(u2_120, ExtendAccess::INSTANCE_OP)
    assert_equal :ok, a1_10.permission?(u3_145, ExtendAccess::INSTANCE_OP)

    assert_nil a2_80.permission?(u1_50, ExtendAccess::INSTANCE_OP)
    assert_nil a2_80.permission?(u2_120, ExtendAccess::INSTANCE_OP)
    assert_equal :ok, a2_80.permission?(u3_145, ExtendAccess::INSTANCE_OP)

    assert_nil a3_110.permission?(u1_50, ExtendAccess::INSTANCE_OP)
    assert_nil a3_110.permission?(u2_120, ExtendAccess::INSTANCE_OP)
    assert_equal :ok, a3_110.permission?(u3_145, ExtendAccess::INSTANCE_OP)

    assert_nil a4_200.permission?(u1_50, ExtendAccess::INSTANCE_OP)
    assert_nil a4_200.permission?(u2_120, ExtendAccess::INSTANCE_OP)
    assert_nil a4_200.permission?(u3_145, ExtendAccess::INSTANCE_OP)
  end
end
