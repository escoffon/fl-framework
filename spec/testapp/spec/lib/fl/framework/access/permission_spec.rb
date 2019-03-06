require 'rails_helper'
require 'test_object_helpers'
require 'test_access_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
  c.include Fl::Framework::Test::AccessHelpers
end

RSpec.describe Fl::Framework::Access::Permission, type: :model do
  before(:example) do
    cleanup_permission_registry()
    @initial_count = Fl::Framework::Access::Permission.class_variable_get(:@@_permission_registry).count
  end
  
  describe "registry" do
    context "built-in permissions" do
      it "should have been registered correctly" do
        xr = [ Fl::Framework::Access::Permission::Read::NAME,
               Fl::Framework::Access::Permission::Write::NAME,
               Fl::Framework::Access::Permission::Delete::NAME,
               Fl::Framework::Access::Permission::Edit::NAME,
               Fl::Framework::Access::Permission::Manage::NAME ]
        
        expect(Fl::Framework::Access::Permission.registered).to match_array(xr)
      end

      it "should have registered grants correctly" do
        pg = Fl::Framework::Access::Permission.permission_grants
        expect(pg.keys).to include(:read, :write, :delete) 
        expect(pg[:read]).to include(:edit, :manage)
        expect(pg[:write]).to include(:edit, :manage)
        expect(pg[:delete]).to include(:manage)
     end
    end
    
    context ".registered" do
      it "should return all registered permissions" do
        p1 = TestPermissionOne.new
        p2 = TestPermissionTwo.new

        xr = [ Fl::Framework::Access::Permission::Read::NAME,
               Fl::Framework::Access::Permission::Write::NAME,
               Fl::Framework::Access::Permission::Delete::NAME,
               Fl::Framework::Access::Permission::Edit::NAME,
               Fl::Framework::Access::Permission::Manage::NAME,
               TestPermissionOne::NAME,
               TestPermissionTwo::NAME ]
        
        expect(Fl::Framework::Access::Permission.registered).to match_array(xr)
      end

    end
    
    context ".lookup" do
      it "should find a registered permission" do
        p1 = TestPermissionOne.new
        p2 = TestPermissionTwo.new
        p3 = TestPermissionThree.new
        p4 = TestPermissionFour.new

        p1_1 = Fl::Framework::Access::Permission.lookup(TestPermissionOne::NAME)
        expect(p1_1).to be_a_kind_of(Fl::Framework::Access::Permission)
        expect(p1_1).to be_an_instance_of(TestPermissionOne)
        expect(p1_1.name).to eql(TestPermissionOne::NAME)
        expect(p1_1.grants.length).to eql(0)

        p4_1 = Fl::Framework::Access::Permission.lookup(TestPermissionFour::NAME)
        expect(p4_1).to be_a_kind_of(Fl::Framework::Access::Permission)
        expect(p4_1).to be_an_instance_of(TestPermissionFour)
        expect(p4_1.name).to eql(TestPermissionFour::NAME)
        expect(p4_1.grants).to include(TestPermissionOne::NAME, TestPermissionTwo::NAME)
      end

      it "should return nil for an unregistered permission" do
        p1 = TestPermissionOne.new
        p2 = TestPermissionTwo.new

        expect(Fl::Framework::Access::Permission.lookup(TestPermissionFour::NAME)).to be_nil
        expect(Fl::Framework::Access::Permission.lookup(:unregistered)).to be_nil
      end        
    end
    
    context ".grants_for_permission" do
      it "should find grants correctly" do
        p1 = TestPermissionOne.new
        p2 = TestPermissionTwo.new
        p3 = TestPermissionThree.new
        p4 = TestPermissionFour.new
        p5 = TestPermissionFive.new
        p6 = TestPermissionSix.new

        pc = Fl::Framework::Access::Permission

        m1 = [ TestPermissionTwo::NAME, TestPermissionThree::NAME, TestPermissionFour::NAME,
               TestPermissionSix::NAME ]
        expect(pc.grants_for_permission(p1.name)).to match_array(m1)

        m2 = [ TestPermissionThree::NAME, TestPermissionFour::NAME, TestPermissionSix::NAME ]
        expect(pc.grants_for_permission(p2.name)).to match_array(m2)

        m3 = [ ]
        expect(pc.grants_for_permission(p3.name)).to match_array(m3)

        m4 = [ ]
        expect(pc.grants_for_permission(p4.name)).to match_array(m4)

        m5 = [ TestPermissionSix::NAME ]
        expect(pc.grants_for_permission(p5.name)).to match_array(m5)

        m6 = [ ]
        expect(pc.grants_for_permission(p6.name)).to match_array(m6)
      end
    end
  end

  describe "#initialize" do
    it "should register an instance automatically" do
      r = Fl::Framework::Access::Permission.class_variable_get(:@@_permission_registry)
      expect(r.count).to eql(@initial_count)
        
      p1 = TestPermissionOne.new
      expect(r.count).to eql(@initial_count + 1)

      p1_1 = Fl::Framework::Access::Permission.lookup(TestPermissionOne::NAME)
      expect(p1_1).not_to be_nil
      expect(p1_1.name).to eql(TestPermissionOne::NAME)
    end

    it "should raise on a duplicate permission" do
      r = Fl::Framework::Access::Permission.class_variable_get(:@@_permission_registry)
      expect(r.count).to eql(@initial_count)
        
      p1 = TestPermissionOne.new
      expect(r.count).to eql(@initial_count + 1)

      expect do
        p1_1 = TestPermissionOne.new
      end.to raise_exception(Fl::Framework::Access::Permission::Duplicate)
    end
  end

  describe "#grants" do
    it "should expand correctly (sequential tests)" do
      p1 = TestPermissionOne.new
      expect(p1.grants.length).to eql(0)
      p2 = TestPermissionTwo.new
      expect(p2.grants).to include(TestPermissionOne::NAME)
      p3 = TestPermissionThree.new
      expect(p3.grants).to include(TestPermissionOne::NAME, TestPermissionTwo::NAME)
      p4 = TestPermissionFour.new
      expect(p4.grants).to include(TestPermissionOne::NAME, TestPermissionTwo::NAME)
    end

    it "should expand correctly (generic tests)" do
      p1 = TestPermissionOne.new
      p2 = TestPermissionTwo.new
      p3 = TestPermissionThree.new
      p4 = TestPermissionFour.new

      expect(p4.grants).to include(TestPermissionOne::NAME, TestPermissionTwo::NAME)
    end

    it "should raise an exception on a missing grant name" do
      p1 = TestPermissionOne.new
      p2 = TestPermissionTwo.new
      p3 = TestPermissionThree.new
      p4 = TestPermissionFour.new

      m = nil
      
      expect do
        begin
          p6 = TestPermissionSix.new
          g = p6.grants
        rescue Fl::Framework::Access::Permission::Missing => x
          m = x.name
          raise x
        end
      end.to raise_exception(Fl::Framework::Access::Permission::Missing)
      expect(m).to eql(:five)
    end
  end
end
