require 'rails_helper'
require 'test_object_helpers'
require 'test_access_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
  c.include Fl::Framework::Test::AccessHelpers
end

class TestAccessCheckerOne < Fl::Framework::Access::Checker
  def initialize()
    super()
  end

  def configure(base)
    base.send(:class_variable_set, :@@_test_access_checker_one, true)
    base.class_eval do
      def self.access_one_class_method()
        'access one class'
      end

      def access_one_instance_method()
        'access one instance'
      end
    end
  end

  def access_check(permission, actor, asset, context = nil)
    sp = permission.to_sym
    return sp if actor.fingerprint == asset.owner.fingerprint
    
    case sp
    when Fl::Framework::Access::Permission::Read::NAME
      if actor.name =~ /reader/
        Fl::Framework::Access::Permission::Read::NAME
      else
        nil
      end
    when Fl::Framework::Access::Permission::Write::NAME
      if actor.name =~ /writer/
        Fl::Framework::Access::Permission::Write::NAME
      else
        nil
      end
    else
      nil
    end
  end
end

class TestAccessCheckerTwo < Fl::Framework::Access::Checker
  def initialize()
    super()
  end

  def access_check(permission, actor, asset, context = nil)
    sp = permission.to_sym
    return sp if actor.fingerprint == asset.owner.fingerprint

    # not the best access check, because a 'reader only' actor will be granted write access, but
    # good enough for testing.
    
    sl = [ sp ] | Fl::Framework::Access::Permission.grants_for_permission(sp)
    sl.each do |s|
      case s
      when Fl::Framework::Access::Permission::Edit::NAME
        return s if actor.name =~ /(reader)|(writer)/
      end
    end

    nil
  end
end

# This class definition adds access methods in one shot

class TestAccessDatumOne
  include Fl::Framework::Access::Access

  has_access_control TestAccessCheckerOne.new()

  attr_reader :owner
  attr_accessor :title
  attr_accessor :value
  
  def initialize(owner, title, value)
    @owner = owner
    @title = title
    @value = value
  end
end

# This class definition adds access methods in two shots; it is how one would add access control
# to an existing class (for example, for Fl::Framework::List::List)

class TestAccessDatumTwo
  attr_reader :owner
  attr_accessor :title
  attr_accessor :value
  
  def initialize(owner, title, value)
    @owner = owner
    @title = title
    @value = value
  end
end

class TestAccessDatumTwo
  include Fl::Framework::Access::Access

  has_access_control TestAccessCheckerTwo.new()
end

RSpec.describe Fl::Framework::Access::Access do
  describe ".has_access_control" do
    it 'should register the access control methods' do
      o1 = create(:test_actor, name: 'owner')
      d1 = TestAccessDatumOne.new(o1, 'd1 title', 'd1')
      d2 = TestAccessDatumTwo.new(o1, 'd2 title', 'd2')

      expect(TestAccessDatumOne.methods).to include(:has_access_control, :access_checker, :permission?)
      expect(TestAccessDatumOne.instance_methods).to include(:access_checker, :permission?)
      expect(d1.methods).to include(:access_checker, :permission?)

      expect(TestAccessDatumOne.access_checker).to be_an_instance_of(TestAccessCheckerOne)
      expect(d1.access_checker).to be_an_instance_of(TestAccessCheckerOne)

      expect(TestAccessDatumTwo.access_checker).to be_an_instance_of(TestAccessCheckerTwo)
      expect(d2.access_checker).to be_an_instance_of(TestAccessCheckerTwo)
    end

    it "should modify class under checker's control" do
      expect(TestAccessDatumOne.class_variables).to include(:@@_test_access_checker_one)
      expect(TestAccessDatumOne.class_variable_get(:@@_test_access_checker_one)).to eql(true)
      expect(TestAccessDatumOne.methods).to include(:access_one_class_method)
      expect(TestAccessDatumOne.access_one_class_method).to eql('access one class')
      o1 = create(:test_actor, name: 'owner')
      d1 = TestAccessDatumOne.new(o1, 'd1 title', 'd1')
      expect(d1.respond_to?(:access_one_instance_method)).to eql(true)
      expect(d1.access_one_instance_method).to eql('access one instance')
    end
  end

  # We mostly check that the correct access checker is called; the behavior of the Checker#access_check
  # method is tested in checker_spec.rb
  
  describe ".permission?" do
    it "should grant or deny permission correctly" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      w1 = create(:test_actor, name: 'reader and writer')
      d1 = TestAccessDatumOne.new(o1, 'd1 title', 'd1')

      g = d1.permission?(Fl::Framework::Access::Permission::Read::NAME, r1)
      expect(g).to eql(Fl::Framework::Access::Permission::Read::NAME)
      g = d1.permission?(Fl::Framework::Access::Permission::Read::NAME, w1)
      expect(g).to eql(Fl::Framework::Access::Permission::Read::NAME)

      g = d1.permission?(Fl::Framework::Access::Permission::Write::NAME, r1)
      expect(g).to be_nil
      g = d1.permission?(Fl::Framework::Access::Permission::Write::NAME, w1)
      expect(g).to eql(Fl::Framework::Access::Permission::Write::NAME)
    end

    it "should grant permission correctly using forward grants" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      w1 = create(:test_actor, name: 'reader and writer')
      d2 = TestAccessDatumTwo.new(o1, 'd2 title', 'd2')

      g = d2.permission?(Fl::Framework::Access::Permission::Read::NAME, r1)
      expect(g).to eql(Fl::Framework::Access::Permission::Edit::NAME)
      g = d2.permission?(Fl::Framework::Access::Permission::Read::NAME, w1)
      expect(g).to eql(Fl::Framework::Access::Permission::Edit::NAME)

      g = d2.permission?(Fl::Framework::Access::Permission::Write::NAME, r1)
      expect(g).to eql(Fl::Framework::Access::Permission::Edit::NAME)
      g = d2.permission?(Fl::Framework::Access::Permission::Write::NAME, w1)
      expect(g).to eql(Fl::Framework::Access::Permission::Edit::NAME)
    end

    it "should deny permission for unknown permission" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      d1 = TestAccessDatumOne.new(o1, 'd1 title', 'd1')

      g = d1.permission?(:unknown, r1)
      expect(g).to be_nil
    end
  end

  describe "#access_checker=" do
    it "should install a custom checker" do
      o1 = create(:test_actor, name: 'owner')
      r1 = create(:test_actor, name: 'reader only')
      w1 = create(:test_actor, name: 'reader and writer')
      d1 = TestAccessDatumOne.new(o1, 'd1 title', 'd1')

      g = d1.permission?(Fl::Framework::Access::Permission::Read::NAME, r1)
      expect(g).to eql(Fl::Framework::Access::Permission::Read::NAME)

      g = d1.permission?(Fl::Framework::Access::Permission::Write::NAME, r1)
      expect(g).to be_nil

      d1.access_checker = Fl::Framework::Access::NullChecker.new

      g = d1.permission?(Fl::Framework::Access::Permission::Read::NAME, r1)
      expect(g).to eql(Fl::Framework::Access::Permission::Read::NAME)

      g = d1.permission?(Fl::Framework::Access::Permission::Write::NAME, r1)
      expect(g).to eql(Fl::Framework::Access::Permission::Write::NAME)

      d10 = TestAccessDatumOne.new(o1, 'd10 title', 'd10')

      g = d10.permission?(Fl::Framework::Access::Permission::Read::NAME, r1)
      expect(g).to eql(Fl::Framework::Access::Permission::Read::NAME)

      g = d10.permission?(Fl::Framework::Access::Permission::Write::NAME, r1)
      expect(g).to be_nil
    end
  end
end
