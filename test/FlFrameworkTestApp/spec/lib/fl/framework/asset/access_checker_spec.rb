require 'rails_helper'
require 'test_object_helpers'
require 'test_access_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
  c.include Fl::Framework::Test::AccessHelpers
end

Fl::Framework::Access::Helper.add_access_control(TestDatumOne, Fl::Framework::Asset::AccessChecker.new())
Fl::Framework::Access::Helper.add_access_control(TestDatumTwo, Fl::Framework::Asset::AccessChecker.new())

def g_map(gl)
  gl.map { |g| "#{g.permission}:#{g.actor.fingerprint}:#{g.data_object.fingerprint}" }
end

RSpec.describe Fl::Framework::Asset::AccessChecker do
  let(:a1) { create(:test_actor) }
  let(:a2) { create(:test_actor) }
  let(:a3) { create(:test_actor) }
  let(:a4) { create(:test_actor) }
  let(:d10) { create(:test_datum_one, owner: a1, value: 10) }
  let(:d11) { create(:test_datum_one, owner: a2, value: 11) }
  let(:d110) { create(:test_datum_one, owner: a2, value: 110) }
  let(:d12) { create(:test_datum_one, owner: a2, value: 12) }
  let(:d20) { create(:test_datum_two, owner: a1, value: 'v20') }
  let(:d21) { create(:test_datum_two, owner: a2, value: 'v21') }
  let(:d22) { create(:test_datum_two, owner: a1, value: 'v22') }
  let(:d30) { create(:test_datum_three, owner: a3, value: 30) }
  let(:d40) { create(:test_datum_four, owner: a3, value: 'v40') }

  let(:g1) do
    Fl::Framework::Asset::AccessGrant.create(asset: d10.asset_record, actor: a2,
                                             permission: Fl::Framework::Access::Permission::Write::NAME)
  end
  let(:g2) do
    Fl::Framework::Asset::AccessGrant.create(asset: d10.asset_record, actor: a3,
                                             permission: Fl::Framework::Access::Permission::Read::NAME)
  end
  let(:g3) do
    Fl::Framework::Asset::AccessGrant.create(asset: d11.asset_record, actor: a1,
                                             permission: Fl::Framework::Access::Permission::Edit::NAME)
  end
  let(:g4) do
    Fl::Framework::Asset::AccessGrant.create(asset: d20.asset_record, actor: a2,
                                             permission: Fl::Framework::Access::Permission::Read::NAME)
  end
  let(:g5) do
    Fl::Framework::Asset::AccessGrant.create(asset: d20.asset_record, actor: a4,
                                             permission: Fl::Framework::Access::Permission::Manage::NAME)
  end
  let(:g6) do
    Fl::Framework::Asset::AccessGrant.create(asset: d21.asset_record, actor: a3,
                                             permission: Fl::Framework::Access::Permission::Read::NAME)
  end
  let(:g7) do
    Fl::Framework::Asset::AccessGrant.create(asset: d21.asset_record, actor: a4,
                                             permission: Fl::Framework::Access::Permission::Read::NAME)
  end
  let(:g8) do
    Fl::Framework::Asset::AccessGrant.create(asset: d12.asset_record, actor: a1,
                                             permission: Fl::Framework::Access::Permission::Edit::NAME)
  end

  context "#configure" do
    it 'should register the custom access control methods' do
      expect(d10.methods).to include(:find_grant, :grant_permission, :revoke_permission,
                                     :create_owner_grant)

      expect(d10._reflections.keys).to include('grants')
    end

    it 'should support automatic creation of the :owner grant' do
      gl = d10.grants.map { |g| g.data_object }
      expect(obj_fingerprints(gl)).to eql(obj_fingerprints([ d10 ]))
      gl = d10.grants.map { |g| g.actor }
      expect(obj_fingerprints(gl)).to eql(obj_fingerprints([ a1 ]))
      gl = d10.grants.map { |g| g.permission.to_sym }
      expect(gl).to eql([ Fl::Framework::Asset::Permission::Owner::NAME ])
    end

    it 'should delete grants when asset is deleted' do
      gl = g_map(d10.grants.map)
      expect(gl).to match_array([ "#{Fl::Framework::Asset::Permission::Owner::NAME}:#{a1.fingerprint}:#{d10.fingerprint}" ])

      ng1 = d10.grants.create(asset: d10.asset_record, actor: a2,
                              permission: Fl::Framework::Access::Permission::Read)
      gl = g_map(d10.grants)
      expect(gl).to match_array([
                                  "#{Fl::Framework::Asset::Permission::Owner::NAME}:#{a1.fingerprint}:#{d10.fingerprint}",
                                  "#{Fl::Framework::Access::Permission::Read::NAME}:#{a2.fingerprint}:#{d10.fingerprint}"
                                ])

      expect do
        d10.destroy
      end.to change(Fl::Framework::Asset::AccessGrant, :count).by(-2)
    end
  end

  context 'grant management' do
    context '#grants' do
      it 'should select only grants for self' do
        # this statement triggers the grant creation
        xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

        gl = d10.grants.map { |g| g.data_object }
        expect(obj_fingerprints(gl)).to eql(obj_fingerprints([ d10, d10, d10 ]))
        gl = d10.grants.map { |g| g.actor }
        expect(obj_fingerprints(gl)).to eql(obj_fingerprints([ a1, a2, a3 ]))
        gl = d10.grants.map { |g| g.permission.to_sym }
        expect(gl).to eql([ Fl::Framework::Asset::Permission::Owner::NAME,
                            Fl::Framework::Access::Permission::Write::NAME,
                            Fl::Framework::Access::Permission::Read::NAME ])

        gl = d21.grants.map { |g| g.data_object }
        expect(obj_fingerprints(gl)).to eql(obj_fingerprints([ d21, d21, d21 ]))
        gl = d21.grants.map { |g| g.actor }
        expect(obj_fingerprints(gl)).to eql(obj_fingerprints([ a2, a3, a4 ]))
        gl = d21.grants.map { |g| g.permission.to_sym }
        expect(gl).to eql([ Fl::Framework::Asset::Permission::Owner::NAME,
                            Fl::Framework::Access::Permission::Read::NAME,
                            Fl::Framework::Access::Permission::Read::NAME ])
      end
    end

    context '#find_grant' do
      it 'should find an existing grant' do
        # this statement triggers the grant creation
        xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

        expect(d10.find_grant(Fl::Framework::Access::Permission::Write::NAME, a2)).not_to be_nil
        expect(d10.find_grant(Fl::Framework::Access::Permission::Write::NAME, a2.fingerprint)).not_to be_nil

        expect(d21.find_grant(Fl::Framework::Access::Permission::Read::NAME, a3)).not_to be_nil
      end

      it 'should return nil for a nonexistent grant' do
        # this statement triggers the grant creation
        xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

        expect(d10.find_grant(Fl::Framework::Access::Permission::Write::NAME, a4)).to be_nil
        expect(d10.find_grant(Fl::Framework::Access::Permission::Write::NAME, a4.fingerprint)).to be_nil

        expect(d21.find_grant(Fl::Framework::Access::Permission::Read::NAME, a1)).to be_nil

        # check permission mismatch as well
        
        expect(d12.find_grant(Fl::Framework::Access::Permission::Edit::NAME, a1)).not_to be_nil
        expect(d12.find_grant(Fl::Framework::Access::Permission::Read::NAME, a1)).to be_nil
      end

      it 'should accept a Permission object' do
        # this statement triggers the grant creation
        xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

        p = Fl::Framework::Access::Permission.lookup(Fl::Framework::Access::Permission::Write::NAME)
        expect(d10.find_grant(p, a2)).not_to be_nil
      end

      it 'should accept a Permission subclass' do
        # this statement triggers the grant creation
        xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

        expect(d10.find_grant(Fl::Framework::Access::Permission::Write, a2)).not_to be_nil
      end
    end

    context '#grant_permission' do
      it 'should create a new grant' do
        g = nil
        
        expect(d10.grants.count).to eql(1)
        expect do
          g = d10.grant_permission(Fl::Framework::Access::Permission::Read::NAME, a4)
        end.to change(Fl::Framework::Asset::AccessGrant, :count).by(1)
      end

      it 'should accept a Permission object' do
        g = nil
        
        expect(d10.grants.count).to eql(1)
        expect do
          p = Fl::Framework::Access::Permission.lookup(Fl::Framework::Access::Permission::Write::NAME)
          g = d10.grant_permission(p, a4)
        end.to change(Fl::Framework::Asset::AccessGrant, :count).by(1)
      end

      it 'should accept a Permission subclass' do
        g = nil
        
        expect(d10.grants.count).to eql(1)
        expect do
          g = d10.grant_permission(Fl::Framework::Access::Permission::Write, a4)
        end.to change(Fl::Framework::Asset::AccessGrant, :count).by(1)
      end

      it 'should be a noop for an existing grant' do
        g = nil
        
        expect(d10.grants.count).to eql(1)
        expect do
          g = d10.grant_permission(Fl::Framework::Access::Permission::Read::NAME, a4)
        end.to change(Fl::Framework::Asset::AccessGrant, :count).by(1)
        expect(d10.grants.count).to eql(2)

        expect do
          g = d10.grant_permission(Fl::Framework::Access::Permission::Read::NAME, a4)
        end.to change(Fl::Framework::Asset::AccessGrant, :count).by(0)
        expect(d10.grants.count).to eql(2)
      end
    end

    context '#revoke_permission' do
      it 'should revoke an existing grant' do
        # this statement triggers the grant creation
        xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

        expect do
          d20.revoke_permission(Fl::Framework::Access::Permission::Read::NAME, a2)
        end.to change(Fl::Framework::Asset::AccessGrant, :count).by(-1)
      end

      it 'should accept a Permission object' do
        # this statement triggers the grant creation
        xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

        expect do
          p = Fl::Framework::Access::Permission.lookup(Fl::Framework::Access::Permission::Manage::NAME)
          d20.revoke_permission(p, a4)
        end.to change(Fl::Framework::Asset::AccessGrant, :count).by(-1)
      end

      it 'should accept a Permission subclass' do
        # this statement triggers the grant creation
        xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

        expect do
          d12.revoke_permission(Fl::Framework::Access::Permission::Edit, a1)
        end.to change(Fl::Framework::Asset::AccessGrant, :count).by(-1)
      end

      it 'should be a noop for a nonexisting grant' do
        # this causes d10 to be created and the :owner grant to be created
        d = d10
        
        expect do
          d10.revoke_permission(Fl::Framework::Access::Permission::Read::NAME, a4)
        end.to change(Fl::Framework::Asset::AccessGrant, :count).by(0)
      end
    end
  end

  context '#check_access' do
    it 'should grant all permissions to owner' do
      checker = Fl::Framework::Asset::AccessChecker.new

      pc = Fl::Framework::Access::Permission::Read
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc, a1, d10)).to eql(pc.name)

      pc = Fl::Framework::Access::Permission::Write
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc, a1, d10)).to eql(pc.name)

      pc = Fl::Framework::Access::Permission::Delete
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc, a1, d10)).to eql(pc.name)

      pc = Fl::Framework::Access::Permission::Edit
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc, a1, d10)).to eql(pc.name)

      pc = Fl::Framework::Access::Permission::Manage
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc, a1, d10)).to eql(pc.name)
    end

    it 'should grant permissions from the access grants (for terminal permissions)' do
      # this statement triggers the grant creation
      xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

      checker = Fl::Framework::Asset::AccessChecker.new

      pc = Fl::Framework::Access::Permission::Read
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d10)).to be_nil
      expect(checker.access_check(pc.name, a3, d10)).to eql(pc.name)
      expect(checker.access_check(pc.name, a4, d10)).to be_nil

      pc = Fl::Framework::Access::Permission::Write
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d10)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d10)).to be_nil
      expect(checker.access_check(pc.name, a4, d10)).to be_nil

      pc = Fl::Framework::Access::Permission::Delete
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d10)).to be_nil
      expect(checker.access_check(pc.name, a3, d10)).to be_nil
      expect(checker.access_check(pc.name, a4, d10)).to be_nil

      pc = Fl::Framework::Access::Permission::Read
      expect(checker.access_check(pc.name, a1, d11)).to eql(Fl::Framework::Access::Permission::Edit::NAME)
      expect(checker.access_check(pc.name, a2, d11)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d11)).to be_nil
      expect(checker.access_check(pc.name, a4, d11)).to be_nil

      pc = Fl::Framework::Access::Permission::Write
      expect(checker.access_check(pc.name, a1, d11)).to eql(Fl::Framework::Access::Permission::Edit::NAME)
      expect(checker.access_check(pc.name, a2, d11)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d11)).to be_nil
      expect(checker.access_check(pc.name, a4, d11)).to be_nil

      pc = Fl::Framework::Access::Permission::Delete
      expect(checker.access_check(pc.name, a1, d11)).to be_nil
      expect(checker.access_check(pc.name, a2, d11)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d11)).to be_nil
      expect(checker.access_check(pc.name, a4, d11)).to be_nil

      pc = Fl::Framework::Access::Permission::Read
      expect(checker.access_check(pc.name, a1, d12)).to eql(Fl::Framework::Access::Permission::Edit::NAME)
      expect(checker.access_check(pc.name, a2, d12)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d12)).to be_nil
      expect(checker.access_check(pc.name, a4, d12)).to be_nil

      pc = Fl::Framework::Access::Permission::Write
      expect(checker.access_check(pc.name, a1, d12)).to eql(Fl::Framework::Access::Permission::Edit::NAME)
      expect(checker.access_check(pc.name, a2, d12)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d12)).to be_nil
      expect(checker.access_check(pc.name, a4, d12)).to be_nil

      pc = Fl::Framework::Access::Permission::Delete
      expect(checker.access_check(pc.name, a1, d12)).to be_nil
      expect(checker.access_check(pc.name, a2, d12)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d12)).to be_nil
      expect(checker.access_check(pc.name, a4, d12)).to be_nil

      pc = Fl::Framework::Access::Permission::Read
      expect(checker.access_check(pc.name, a1, d20)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d20)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d20)).to be_nil
      expect(checker.access_check(pc.name, a4, d20)).to eql(Fl::Framework::Access::Permission::Manage::NAME)

      pc = Fl::Framework::Access::Permission::Write
      expect(checker.access_check(pc.name, a1, d20)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d20)).to be_nil
      expect(checker.access_check(pc.name, a3, d20)).to be_nil
      expect(checker.access_check(pc.name, a4, d20)).to eql(Fl::Framework::Access::Permission::Manage::NAME)

      pc = Fl::Framework::Access::Permission::Delete
      expect(checker.access_check(pc.name, a1, d20)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d20)).to be_nil
      expect(checker.access_check(pc.name, a3, d20)).to be_nil
      expect(checker.access_check(pc.name, a4, d20)).to eql(Fl::Framework::Access::Permission::Manage::NAME)

      pc = Fl::Framework::Access::Permission::Read
      expect(checker.access_check(pc.name, a1, d21)).to be_nil
      expect(checker.access_check(pc.name, a2, d21)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d21)).to eql(pc.name)
      expect(checker.access_check(pc.name, a4, d21)).to eql(pc.name)

      pc = Fl::Framework::Access::Permission::Write
      expect(checker.access_check(pc.name, a1, d21)).to be_nil
      expect(checker.access_check(pc.name, a2, d21)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d21)).to be_nil
      expect(checker.access_check(pc.name, a4, d21)).to be_nil

      pc = Fl::Framework::Access::Permission::Delete
      expect(checker.access_check(pc.name, a1, d21)).to be_nil
      expect(checker.access_check(pc.name, a2, d21)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d21)).to be_nil
      expect(checker.access_check(pc.name, a4, d21)).to be_nil

      pc = Fl::Framework::Access::Permission::Read
      expect(checker.access_check(pc.name, a1, d22)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d22)).to be_nil
      expect(checker.access_check(pc.name, a3, d22)).to be_nil
      expect(checker.access_check(pc.name, a4, d22)).to be_nil

      pc = Fl::Framework::Access::Permission::Write
      expect(checker.access_check(pc.name, a1, d22)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d22)).to be_nil
      expect(checker.access_check(pc.name, a3, d22)).to be_nil
      expect(checker.access_check(pc.name, a4, d22)).to be_nil

      pc = Fl::Framework::Access::Permission::Delete
      expect(checker.access_check(pc.name, a1, d22)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d22)).to be_nil
      expect(checker.access_check(pc.name, a3, d22)).to be_nil
      expect(checker.access_check(pc.name, a4, d22)).to be_nil
    end

    it 'should grant permissions from the access grants (for forwarding permissions)' do
      # this statement triggers the grant creation
      xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse

      checker = Fl::Framework::Asset::AccessChecker.new

      pc = Fl::Framework::Access::Permission::Edit
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d10)).to be_nil
      expect(checker.access_check(pc.name, a3, d10)).to be_nil
      expect(checker.access_check(pc.name, a4, d10)).to be_nil

      pc = Fl::Framework::Access::Permission::Manage
      expect(checker.access_check(pc.name, a1, d10)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d10)).to be_nil
      expect(checker.access_check(pc.name, a3, d10)).to be_nil
      expect(checker.access_check(pc.name, a4, d10)).to be_nil

      pc = Fl::Framework::Access::Permission::Edit
      expect(checker.access_check(pc.name, a1, d11)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d11)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d11)).to be_nil
      expect(checker.access_check(pc.name, a4, d11)).to be_nil

      pc = Fl::Framework::Access::Permission::Manage
      expect(checker.access_check(pc.name, a1, d11)).to be_nil
      expect(checker.access_check(pc.name, a2, d11)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d11)).to be_nil
      expect(checker.access_check(pc.name, a4, d11)).to be_nil

      pc = Fl::Framework::Access::Permission::Edit
      expect(checker.access_check(pc.name, a1, d12)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d12)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d12)).to be_nil
      expect(checker.access_check(pc.name, a4, d12)).to be_nil

      pc = Fl::Framework::Access::Permission::Manage
      expect(checker.access_check(pc.name, a1, d12)).to be_nil
      expect(checker.access_check(pc.name, a2, d12)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d12)).to be_nil
      expect(checker.access_check(pc.name, a4, d12)).to be_nil

      pc = Fl::Framework::Access::Permission::Edit
      expect(checker.access_check(pc.name, a1, d20)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d20)).to be_nil
      expect(checker.access_check(pc.name, a3, d20)).to be_nil
      expect(checker.access_check(pc.name, a4, d20)).to eql(Fl::Framework::Access::Permission::Manage::NAME)

      pc = Fl::Framework::Access::Permission::Manage
      expect(checker.access_check(pc.name, a1, d20)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d20)).to be_nil
      expect(checker.access_check(pc.name, a3, d20)).to be_nil
      expect(checker.access_check(pc.name, a4, d20)).to eql(pc.name)

      pc = Fl::Framework::Access::Permission::Edit
      expect(checker.access_check(pc.name, a1, d21)).to be_nil
      expect(checker.access_check(pc.name, a2, d21)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d21)).to be_nil
      expect(checker.access_check(pc.name, a4, d21)).to be_nil

      pc = Fl::Framework::Access::Permission::Manage
      expect(checker.access_check(pc.name, a1, d21)).to be_nil
      expect(checker.access_check(pc.name, a2, d21)).to eql(pc.name)
      expect(checker.access_check(pc.name, a3, d21)).to be_nil
      expect(checker.access_check(pc.name, a4, d21)).to be_nil

      pc = Fl::Framework::Access::Permission::Edit
      expect(checker.access_check(pc.name, a1, d22)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d22)).to be_nil
      expect(checker.access_check(pc.name, a3, d22)).to be_nil
      expect(checker.access_check(pc.name, a4, d22)).to be_nil

      pc = Fl::Framework::Access::Permission::Manage
      expect(checker.access_check(pc.name, a1, d22)).to eql(pc.name)
      expect(checker.access_check(pc.name, a2, d22)).to be_nil
      expect(checker.access_check(pc.name, a3, d22)).to be_nil
      expect(checker.access_check(pc.name, a4, d22)).to be_nil
    end
  end
end
