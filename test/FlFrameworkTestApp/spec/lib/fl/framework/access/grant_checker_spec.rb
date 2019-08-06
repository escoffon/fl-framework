require 'rails_helper'
require 'test_object_helpers'
require 'test_access_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
  c.include Fl::Framework::Test::AccessHelpers
end

Fl::Framework::Access::Helper.add_access_control(TestDatumOne, Fl::Framework::Access::GrantChecker.new())
Fl::Framework::Access::Helper.add_access_control(TestDatumTwo, Fl::Framework::Access::GrantChecker.new())

def g_map(gl)
  gl.map { |g| "#{g.permissions}:#{g.granted_to.fingerprint}:#{g.target.fingerprint}" }
end

RSpec.describe Fl::Framework::Access::GrantChecker do
  let(:_a) { Fl::Framework::Access }
  let(:_ap) { _a::Permission }
  let(:_ag) { _a::Grant }
  
  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }
  let(:a4) { create(:test_actor, name: 'a4') }
  
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
    p = Fl::Framework::Access::Permission::Write::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d10, granted_to: a2, grants: pm)
  end
  let(:g2) do
    p = Fl::Framework::Access::Permission::Read::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d10, granted_to: a3, grants: pm)
  end
  let(:g3) do
    p = Fl::Framework::Access::Permission::Edit::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d11, granted_to: a1, grants: pm)
  end
  let(:g4) do
    p = Fl::Framework::Access::Permission::Read::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d20, granted_to: a2, grants: pm)
  end
  let(:g5) do
    p = Fl::Framework::Access::Permission::Edit::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d20, granted_to: a4, grants: pm)
  end
  let(:g6) do
    p = Fl::Framework::Access::Permission::Read::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d21, granted_to: a3, grants: pm)
  end
  let(:g7) do
    p = Fl::Framework::Access::Permission::Read::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d21, granted_to: a4, grants: pm)
  end
  let(:g8) do
    p = Fl::Framework::Access::Permission::Write::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d12, granted_to: a1, grants: pm)
  end
  let(:g9) do
    p = Fl::Framework::Access::Permission::Manage::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d30, granted_to: a4, grants: pm)
  end
  let(:g10) do
    p = Fl::Framework::Access::Permission::Read::NAME
    pm = Fl::Framework::Access::Permission.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d40, granted_to: a4, grants: pm)
  end

  context "#configure" do
    it 'should register the custom access control methods' do
      expect(d10.class.included_modules).to include(Fl::Framework::Access::Target)
      expect(d10.methods).to include(:find_grant_to, :grant_permission_to, :revoke_permission_from,
                                     :delete_target_grants, :create_owner_grant)
    end

    it 'should support automatic creation of the :owner grant' do
      g = _ag.find_grant(d10.owner, d10)
      expect(g).to be_a(_ag)
      expect(g.grants & _ap::Owner::BIT).to eql(_ap::Owner::BIT)
    end

    it 'should delete grants when target is deleted' do
      xl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]
      
      gq = _ag.build_query(only_targets: d20)
      expect(gq.count).to eql(3)
      
      expect do
        d20.destroy
      end.to change(Fl::Framework::Access::Grant, :count).by(-3)
    end
  end

  describe '#check_access' do
    it 'should grant all permissions to owner' do
      checker = Fl::Framework::Access::GrantChecker.new

      pc = _ap::Read
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc, a1, d10)).to eql(true)

      pc = _ap::Write
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc, a1, d10)).to eql(true)

      pc = _ap::Delete
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc, a1, d10)).to eql(true)

      pc = _ap::Edit
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc, a1, d10)).to eql(true)

      pc = _ap::Manage
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc, a1, d10)).to eql(true)
    end

    it 'should grant permissions from the access grants (primitive permissions)' do
      # this statement triggers the grant creation
      xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]

      checker = Fl::Framework::Access::GrantChecker.new

      pc = _ap::Read
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d10)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d10)).to eql(true)
      expect(checker.access_check(pc::NAME, a4, d10)).to eql(false)

      pc = _ap::Write
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d10)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d10)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d10)).to eql(false)

      pc = _ap::Delete
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d10)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d10)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d10)).to eql(false)

      pc = _ap::Read
      expect(checker.access_check(pc::NAME, a1, d11)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d11)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d11)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d11)).to eql(false)

      pc = _ap::Write
      expect(checker.access_check(pc::NAME, a1, d11)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d11)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d11)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d11)).to eql(false)

      pc = _ap::Delete
      expect(checker.access_check(pc::NAME, a1, d11)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d11)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d11)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d11)).to eql(false)

      pc = _ap::Read
      expect(checker.access_check(pc::NAME, a1, d12)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d12)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d12)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d12)).to eql(false)

      pc = _ap::Write
      expect(checker.access_check(pc::NAME, a1, d12)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d12)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d12)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d12)).to eql(false)

      pc = _ap::Delete
      expect(checker.access_check(pc::NAME, a1, d12)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d12)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d12)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d12)).to eql(false)

      pc = _ap::Read
      expect(checker.access_check(pc::NAME, a1, d20)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d20)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d20)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d20)).to eql(true)

      pc = _ap::Write
      expect(checker.access_check(pc::NAME, a1, d20)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d20)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d20)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d20)).to eql(true)

      pc = _ap::Delete
      expect(checker.access_check(pc::NAME, a1, d20)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d20)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d20)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d20)).to eql(false)

      pc = _ap::Read
      expect(checker.access_check(pc::NAME, a1, d21)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d21)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d21)).to eql(true)
      expect(checker.access_check(pc::NAME, a4, d21)).to eql(true)

      pc = _ap::Write
      expect(checker.access_check(pc::NAME, a1, d21)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d21)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d21)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d21)).to eql(false)

      pc = _ap::Delete
      expect(checker.access_check(pc::NAME, a1, d21)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d21)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d21)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d21)).to eql(false)

      pc = _ap::Read
      expect(checker.access_check(pc::NAME, a1, d22)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d22)).to eql(false)

      pc = _ap::Write
      expect(checker.access_check(pc::NAME, a1, d22)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d22)).to eql(false)

      pc = _ap::Delete
      expect(checker.access_check(pc::NAME, a1, d22)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d22)).to eql(false)
    end

    it 'should grant permissions from the access grants (composite permissions)' do
      # this statement triggers the grant creation
      xl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      checker = Fl::Framework::Access::GrantChecker.new

      pc = _ap::Edit
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d10)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d10)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d10)).to eql(false)

      pc = _ap::Manage
      expect(checker.access_check(pc::NAME, a1, d10)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d10)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d10)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d10)).to eql(false)

      pc = _ap::Edit
      expect(checker.access_check(pc::NAME, a1, d11)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d11)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d11)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d11)).to eql(false)

      pc = _ap::Manage
      expect(checker.access_check(pc::NAME, a1, d11)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d11)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d11)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d11)).to eql(false)

      pc = _ap::Edit
      expect(checker.access_check(pc::NAME, a1, d12)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d12)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d12)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d12)).to eql(false)

      pc = _ap::Manage
      expect(checker.access_check(pc::NAME, a1, d12)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d12)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d12)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d12)).to eql(false)

      pc = _ap::Edit
      expect(checker.access_check(pc::NAME, a1, d20)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d20)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d20)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d20)).to eql(true)

      pc = _ap::Manage
      expect(checker.access_check(pc::NAME, a1, d20)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d20)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d20)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d20)).to eql(false)

      pc = _ap::Edit
      expect(checker.access_check(pc::NAME, a1, d21)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d21)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d21)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d21)).to eql(false)

      pc = _ap::Manage
      expect(checker.access_check(pc::NAME, a1, d21)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d21)).to eql(true)
      expect(checker.access_check(pc::NAME, a3, d21)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d21)).to eql(false)

      pc = _ap::Edit
      expect(checker.access_check(pc::NAME, a1, d22)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d22)).to eql(false)

      pc = _ap::Manage
      expect(checker.access_check(pc::NAME, a1, d22)).to eql(true)
      expect(checker.access_check(pc::NAME, a2, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d22)).to eql(false)
      expect(checker.access_check(pc::NAME, a4, d22)).to eql(false)

      pc = _ap::Edit
      expect(checker.access_check(pc::NAME, a1, d30)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d30)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d30)).to eql(true)
      expect(checker.access_check(pc::NAME, a4, d30)).to eql(true)

      pc = _ap::Manage
      expect(checker.access_check(pc::NAME, a1, d30)).to eql(false)
      expect(checker.access_check(pc::NAME, a2, d30)).to eql(false)
      expect(checker.access_check(pc::NAME, a3, d30)).to eql(true)
      expect(checker.access_check(pc::NAME, a4, d30)).to eql(true)
    end
  end
end
