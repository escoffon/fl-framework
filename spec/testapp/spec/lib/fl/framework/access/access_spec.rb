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

class TestAccessDatumTwo
  include Fl::Framework::Access::Access

  has_access_control TestAccessCheckerTwo.new()

  attr_reader :owner
  attr_accessor :title
  attr_accessor :value
  
  def initialize(owner, title, value)
    @owner = owner
    @title = title
    @value = value
  end
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
  end
end
