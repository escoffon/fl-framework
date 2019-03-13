require 'rails_helper'
require 'test_object_helpers'
require 'test_access_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
  c.include Fl::Framework::Test::AccessHelpers
end

class MyBase < Fl::Framework::Access::Permission
  NAME = :my_base
end

class MyPermission < MyBase
  NAME = :my_permission

  def initialize()
    super(NAME, [ ])
  end
end

MyPermission.new

class B
end

class S < B
end

RSpec.describe Fl::Framework::Access::Permission, type: :model do
  describe ".permission_name" do
    it "should return symbol and string arguments" do
      n = Fl::Framework::Access::Permission::Read::NAME
      expect(Fl::Framework::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Framework::Access::Helper.permission_name(n.to_s)).to eql(n)

      n = Fl::Framework::Access::Permission::Write::NAME
      expect(Fl::Framework::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Framework::Access::Helper.permission_name(n.to_s)).to eql(n)

      n = Fl::Framework::Access::Permission::Delete::NAME
      expect(Fl::Framework::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Framework::Access::Helper.permission_name(n.to_s)).to eql(n)

      n = Fl::Framework::Access::Permission::Edit::NAME
      expect(Fl::Framework::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Framework::Access::Helper.permission_name(n.to_s)).to eql(n)

      n = Fl::Framework::Access::Permission::Manage::NAME
      expect(Fl::Framework::Access::Helper.permission_name(n)).to eql(n)
      expect(Fl::Framework::Access::Helper.permission_name(n.to_s)).to eql(n)
    end

    it "should process Permission arguments" do
      n = Fl::Framework::Access::Permission::Read::NAME
      p = Fl::Framework::Access::Permission.lookup(n)
      expect(Fl::Framework::Access::Helper.permission_name(p)).to eql(n)

      n = Fl::Framework::Access::Permission::Write::NAME
      p = Fl::Framework::Access::Permission.lookup(n)
      expect(Fl::Framework::Access::Helper.permission_name(p)).to eql(n)

      n = Fl::Framework::Access::Permission::Delete::NAME
      p = Fl::Framework::Access::Permission.lookup(n)
      expect(Fl::Framework::Access::Helper.permission_name(p)).to eql(n)

      n = Fl::Framework::Access::Permission::Edit::NAME
      p = Fl::Framework::Access::Permission.lookup(n)
      expect(Fl::Framework::Access::Helper.permission_name(p)).to eql(n)

      n = Fl::Framework::Access::Permission::Manage::NAME
      p = Fl::Framework::Access::Permission.lookup(n)
      expect(Fl::Framework::Access::Helper.permission_name(p)).to eql(n)
    end

    it "should process Class arguments" do
      n = Fl::Framework::Access::Permission::Read::NAME
      c = Fl::Framework::Access::Permission::Read
      expect(Fl::Framework::Access::Helper.permission_name(c)).to eql(n)

      n = Fl::Framework::Access::Permission::Write::NAME
      c = Fl::Framework::Access::Permission::Write
      expect(Fl::Framework::Access::Helper.permission_name(c)).to eql(n)

      n = Fl::Framework::Access::Permission::Delete::NAME
      c = Fl::Framework::Access::Permission::Delete
      expect(Fl::Framework::Access::Helper.permission_name(c)).to eql(n)

      n = Fl::Framework::Access::Permission::Edit::NAME
      c = Fl::Framework::Access::Permission::Edit
      expect(Fl::Framework::Access::Helper.permission_name(c)).to eql(n)

      n = Fl::Framework::Access::Permission::Manage::NAME
      c = Fl::Framework::Access::Permission::Manage
      expect(Fl::Framework::Access::Helper.permission_name(c)).to eql(n)

      n = MyPermission::NAME
      c = MyPermission
      expect(Fl::Framework::Access::Helper.permission_name(c)).to eql(n)

      expect(Fl::Framework::Access::Helper.permission_name(S)).to be_nil
    end
  end
end
