require 'rails_helper'
require 'test_object_helpers'
require 'test_access_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
  c.include Fl::Framework::Test::AccessHelpers
end

RSpec.describe Fl::Framework::Access::Target do
  let(:_a) { Fl::Framework::Access }
  let(:_ap) { _a::Permission }
  let(:_ag) { _a::Grant }

  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }
  let(:a4) { create(:test_actor, name: 'a4') }

  let(:d10) do
    d10 = create(:test_datum_one, owner: a1, value: 10)

    p = _ap::Edit::NAME
    pm = _ap.permission_mask(p)
    Fl::Framework::Access::Grant.add_grant(pm, a2, d10)

    p = _ap::Read::NAME
    pm = _ap.permission_mask(p)
    Fl::Framework::Access::Grant.add_grant(pm, a3, d10)

    d10
  end

  let(:d11) do
    d11 = create(:test_datum_one, owner: a2, value: 11)

    p = _ap::Manage::NAME
    pm = _ap.permission_mask(p)
    Fl::Framework::Access::Grant.add_grant(pm, a4, d11)

    d11
  end

  let(:d12) { create(:test_datum_one, owner: a4, value: 12) }
  
  context 'when included' do
    it 'should register instance methods' do
      expect(TestDatumOne.instance_methods).to include(:find_grant_to, :grant_permission_to,
                                                       :revoke_permission_from, :create_owner_grant,
                                                       :delete_target_grants)
      expect(d10.methods).to include(:find_grant_to, :grant_permission_to,
                                     :revoke_permission_from, :create_owner_grant,
                                     :delete_target_grants)
    end
  end

  context '#find_grant_to' do
    it 'should find the correct grant' do
      g = d10.find_grant_to(a1)
      expect(g).to be_a(_ag)
      expect(g.granted_to.fingerprint).to eql(a1.fingerprint)
      expect(g.target.fingerprint).to eql(d10.fingerprint)
      p = _ap::Owner::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)

      g = d10.find_grant_to(a2)
      expect(g).to be_a(_ag)
      expect(g.granted_to.fingerprint).to eql(a2.fingerprint)
      expect(g.target.fingerprint).to eql(d10.fingerprint)
      p = _ap::Edit::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)

      g = d11.find_grant_to(a4)
      expect(g).to be_a(_ag)
      expect(g.granted_to.fingerprint).to eql(a4.fingerprint)
      expect(g.target.fingerprint).to eql(d11.fingerprint)
      p = _ap::Manage::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)

      g = d11.find_grant_to(a3)
      expect(g).to be_nil
    end
  end

  context '#grant_permission_to' do
    it 'should add a grant' do
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d12.fingerprint)
      expect(gq.count).to eql(1)

      g1 = d12.grant_permission_to(_ap.permission_mask(_ap::Read), a1)
      g2 = d12.grant_permission_to(_ap.permission_mask(_ap::Edit), a2)
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d12.fingerprint)
      expect(gq.count).to eql(3)
    end

    it 'should amend an existing grant' do
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d12.fingerprint)
      expect(gq.count).to eql(1)

      g1 = d12.grant_permission_to(_ap.permission_mask(_ap::Read), a1)
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d12.fingerprint)
      expect(gq.count).to eql(2)

      g1_1 = d12.grant_permission_to(_ap.permission_mask(_ap::Write), a1)
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d12.fingerprint)
      expect(gq.count).to eql(2)
      expect(g1.id).to eql(g1_1.id)
      expect(g1_1.grants).to eql(_ap::Read::BIT | _ap::Write::BIT)
    end
  end

  context '#revoke_permission_from' do
    it 'should amend an existing grant' do
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(3)
      g = d10.find_grant_to(a2)
      p = _ap::Edit::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)

      d10.revoke_permission_from(_ap.permission_mask(_ap::Read), a2)
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(3)
      g = d10.find_grant_to(a2)
      p = _ap::Write::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)
    end

    it 'should remove a grant with empty permissions' do
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(3)

      d10.revoke_permission_from(_ap.permission_mask(_ap::Read), a3)
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(2)
    end

    it 'should be a no-op if grant is not present' do
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(3)

      d10.revoke_permission_from(_ap.permission_mask(_ap::Read), a4)
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(3)
    end

    it 'should be a no-op if permission is already revoked' do
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(3)
      g = d10.find_grant_to(a3)
      p = _ap::Read::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)

      d10.revoke_permission_from(_ap.permission_mask(_ap::Write), a3)
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(3)
      g = d10.find_grant_to(a3)
      p = _ap::Read::NAME
      pm = _ap.permission_mask(p)
      expect(g.grants).to eql(pm)
    end
  end
  
  context 'before_destroy callback' do
    it 'should remove all grants for the target' do
      # this creates the grants
      dl = [ d10, d11 ]

      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(3)
      expect do
        d10.destroy
      end.to change(_ag, :count).by(-3)
      gq = _ag.where('(target_fingerprint = :tfp)', tfp: d10.fingerprint)
      expect(gq.count).to eql(0)
    end
  end
end
