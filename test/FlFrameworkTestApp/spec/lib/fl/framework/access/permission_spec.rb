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
    cleanup_permission_registry([ TestAccess::P1::NAME, TestAccess::P2::NAME, TestAccess::P3::NAME,
                                  TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ])

    @initial_count = Fl::Framework::Access::Permission.instance_variable_get(:@_permission_registry).count
  end
  
  describe "registry" do
    context "built-in permissions" do
      it "should have been registered correctly" do
        xr = [ Fl::Framework::Access::Permission::Read::NAME,
               Fl::Framework::Access::Permission::Write::NAME,
               Fl::Framework::Access::Permission::Delete::NAME,
               Fl::Framework::Access::Permission::Edit::NAME,
               Fl::Framework::Access::Permission::Manage::NAME,
               Fl::Framework::Access::Permission::Create::NAME,
               Fl::Framework::Asset::Permission::Owner::NAME,
               Fl::Framework::List::Permission::ManageItems::NAME ]
        
        expect(Fl::Framework::Access::Permission.registered).to match_array(xr)
      end

      it "should have registered grants correctly" do
        pg = Fl::Framework::Access::Permission.permission_grantors
        expect(pg.keys).to match_array([ :read, :write, :delete, :edit, :manage,
                                         :create, :manage_items, :owner ])
        expect(pg[:read]).to match_array([ :edit, :manage ])
        expect(pg[:write]).to match_array([ :edit, :manage ])
        expect(pg[:delete]).to match_array([ :manage ])
        expect(pg[:edit]).to match_array([ :manage ])
        expect(pg[:manage]).to match_array([ ])
        expect(pg[:create]).to match_array([ ])
        expect(pg[:manage_items]).to match_array([ ])
        expect(pg[:owner]).to match_array([ ])
      end

      it "should have appropriate class name accessors" do
        expect(Fl::Framework::Access::Permission::Read.name).to eql(Fl::Framework::Access::Permission::Read::NAME)
        expect(Fl::Framework::Access::Permission::Write.name).to eql(Fl::Framework::Access::Permission::Write::NAME)
        expect(Fl::Framework::Access::Permission::Delete.name).to eql(Fl::Framework::Access::Permission::Delete::NAME)
        expect(Fl::Framework::Access::Permission::Edit.name).to eql(Fl::Framework::Access::Permission::Edit::NAME)
        expect(Fl::Framework::Access::Permission::Manage.name).to eql(Fl::Framework::Access::Permission::Manage::NAME)
      end
    end
    
    context ".registered" do
      it "should return all registered permissions" do
        mp1 = TestAccess::P1.new
        mp2 = TestAccess::P2.new

        xr = [ Fl::Framework::Access::Permission::Read::NAME,
               Fl::Framework::Access::Permission::Write::NAME,
               Fl::Framework::Access::Permission::Delete::NAME,
               Fl::Framework::Access::Permission::Edit::NAME,
               Fl::Framework::Access::Permission::Manage::NAME,
               Fl::Framework::Access::Permission::Create::NAME,
               Fl::Framework::Asset::Permission::Owner::NAME,
               Fl::Framework::List::Permission::ManageItems::NAME,
               TestAccess::P1::NAME,
               TestAccess::P2::NAME ]
        
        expect(Fl::Framework::Access::Permission.registered).to match_array(xr)
      end

    end
    
    context ".lookup" do
      it "should find a registered permission" do
        mp1 = TestAccess::P1.new
        mp2 = TestAccess::P2.new
        mp3 = TestAccess::P3.new
        mp4 = TestAccess::P4.new

        p1_1 = Fl::Framework::Access::Permission.lookup(TestAccess::P1::NAME)
        expect(p1_1).to be_a_kind_of(Fl::Framework::Access::Permission)
        expect(p1_1).to be_an_instance_of(TestAccess::P1)
        expect(p1_1.name).to eql(TestAccess::P1::NAME)
        expect(p1_1.grantors).to contain_exactly(TestAccess::P4::NAME)

        p4_1 = Fl::Framework::Access::Permission.lookup(TestAccess::P4::NAME)
        expect(p4_1).to be_a_kind_of(Fl::Framework::Access::Permission)
        expect(p4_1).to be_an_instance_of(TestAccess::P4)
        expect(p4_1.name).to eql(TestAccess::P4::NAME)
        expect(p4_1.grantors).to contain_exactly()
      end

      it "should return nil for an unregistered permission" do
        mp1 = TestAccess::P1.new
        mp2 = TestAccess::P2.new

        expect(Fl::Framework::Access::Permission.lookup(TestAccess::P4::NAME)).to be_nil
        expect(Fl::Framework::Access::Permission.lookup(:unregistered)).to be_nil
      end        

      it "should accept string arguments" do
        mp1 = TestAccess::P1.new
        mp2 = TestAccess::P2.new
        mp3 = TestAccess::P3.new
        mp4 = TestAccess::P4.new

        p1 = Fl::Framework::Access::Permission.lookup(TestAccess::P1::NAME.to_s)
        expect(p1).to be_an_instance_of(TestAccess::P1)
      end
    end
    
    context ".grantors_for_permission" do
      it "should find grantors correctly" do
        mp1 = TestAccess::P1.new
        mp2 = TestAccess::P2.new
        mp3 = TestAccess::P3.new
        mp4 = TestAccess::P4.new
        mp5 = TestAccess::P5.new
        mp6 = TestAccess::P6.new

        pc = Fl::Framework::Access::Permission

        m1 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp1.name)).to match_array(m1)

        m2 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp2.name)).to match_array(m2)

        m3 = [ TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp3.name)).to match_array(m3)

        m4 = [ TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp4.name)).to match_array(m4)

        m5 = [ TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp5.name)).to match_array(m5)

        m6 = [ ]
        expect(pc.grantors_for_permission(mp6.name)).to match_array(m6)
      end

      it "should accept string arguments" do
        mp1 = TestAccess::P1.new
        mp2 = TestAccess::P2.new
        mp3 = TestAccess::P3.new
        mp4 = TestAccess::P4.new
        mp5 = TestAccess::P5.new
        mp6 = TestAccess::P6.new

        pc = Fl::Framework::Access::Permission

        m1 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp1.name.to_s)).to match_array(m1)
      end

      it "should accept instance arguments" do
        mp1 = TestAccess::P1.new
        mp2 = TestAccess::P2.new
        mp3 = TestAccess::P3.new
        mp4 = TestAccess::P4.new
        mp5 = TestAccess::P5.new
        mp6 = TestAccess::P6.new

        pc = Fl::Framework::Access::Permission

        m1 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(mp1)).to match_array(m1)
      end

      it "should accept class arguments" do
        mp1 = TestAccess::P1.new
        mp2 = TestAccess::P2.new
        mp3 = TestAccess::P3.new
        mp4 = TestAccess::P4.new
        mp5 = TestAccess::P5.new
        mp6 = TestAccess::P6.new

        pc = Fl::Framework::Access::Permission

        m1 = [ TestAccess::P4::NAME, TestAccess::P5::NAME, TestAccess::P6::NAME ]
        expect(pc.grantors_for_permission(TestAccess::P1)).to match_array(m1)
      end
    end
  end

  describe "#initialize" do
    it "should register an instance automatically" do
      r = Fl::Framework::Access::Permission.instance_variable_get(:@_permission_registry)
      expect(r.count).to eql(@initial_count)
        
      mp1 = TestAccess::P1.new
      expect(r.count).to eql(@initial_count + 1)

      p1 = Fl::Framework::Access::Permission.lookup(TestAccess::P1::NAME)
      expect(p1).not_to be_nil
      expect(p1.name).to eql(TestAccess::P1::NAME)
    end

    it "should raise on a duplicate permission" do
      r = Fl::Framework::Access::Permission.instance_variable_get(:@_permission_registry)
      expect(r.count).to eql(@initial_count)
        
      mp1 = TestAccess::P1.new
      expect(r.count).to eql(@initial_count + 1)

      expect do
        mp1_1 = TestAccess::P1.new
      end.to raise_exception(Fl::Framework::Access::Permission::Duplicate)
    end
  end

  describe "#grantors" do
    it "should expand correctly (sequential tests)" do
      mp1 = TestAccess::P1.new
      expect(mp1.grantors).to match_array([ ])
      mp2 = TestAccess::P2.new
      expect(mp1.grantors).to match_array([ ])
      expect(mp2.grantors).to match_array([ ])
      mp3 = TestAccess::P3.new
      expect(mp1.grantors).to match_array([ ])
      expect(mp2.grantors).to match_array([ ])
      expect(mp3.grantors).to match_array([ ])
      mp4 = TestAccess::P4.new
      expect(mp1.grantors).to match_array([ TestAccess::P4::NAME ])
      expect(mp2.grantors).to match_array([ TestAccess::P4::NAME ])
      expect(mp3.grantors).to match_array([ ])
      expect(mp4.grantors).to match_array([ ])
      mp5 = TestAccess::P5.new
      expect(mp1.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME ])
      expect(mp2.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME ])
      expect(mp3.grantors).to match_array([ TestAccess::P5::NAME ])
      expect(mp4.grantors).to match_array([ TestAccess::P5::NAME ])
      expect(mp5.grantors).to match_array([ ])
      mp6 = TestAccess::P6.new
      expect(mp1.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME,
                                            TestAccess::P6::NAME ])
      expect(mp2.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME,
                                            TestAccess::P6::NAME ])
      expect(mp3.grantors).to match_array([ TestAccess::P5::NAME, TestAccess::P6::NAME ])
      expect(mp4.grantors).to match_array([ TestAccess::P5::NAME, TestAccess::P6::NAME ])
      expect(mp5.grantors).to match_array([ TestAccess::P6::NAME ])
      expect(mp6.grantors).to match_array([ ])
    end

    it "should expand correctly (generic tests)" do
      mp1 = TestAccess::P1.new
      mp2 = TestAccess::P2.new
      mp3 = TestAccess::P3.new
      mp4 = TestAccess::P4.new
      mp5 = TestAccess::P5.new
      mp6 = TestAccess::P6.new
      expect(mp1.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME,
                                            TestAccess::P6::NAME ])
      expect(mp2.grantors).to match_array([ TestAccess::P4::NAME, TestAccess::P5::NAME,
                                            TestAccess::P6::NAME ])
      expect(mp3.grantors).to match_array([ TestAccess::P5::NAME, TestAccess::P6::NAME ])
      expect(mp4.grantors).to match_array([ TestAccess::P5::NAME, TestAccess::P6::NAME ])
      expect(mp5.grantors).to match_array([ TestAccess::P6::NAME ])
      expect(mp6.grantors).to match_array([ ])
    end
  end
end
