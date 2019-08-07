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

def actor_owner_grants(actor)
  _ag.build_query(only_granted_to: actor, permissions: { all: _ap::Owner::BIT })
end

def target_owner_grants(target)
  _ag.build_query(only_targets: target, permissions: { all: _ap::Owner::BIT })
end

def extract_targets(gl)
  gl.map do |g|
    t = g.target
    "#{t.fingerprint} - #{t.value}"
  end
end

def extract_grants(gl)
  gl.map do |g|
    a = g.granted_to
    t = g.target
    #"#{sprintf('0x%08x', g.grants)} - #{a.fingerprint} - #{a.name} - #{t.fingerprint} - #{t.value}"
    "#{sprintf('0x%08x', g.grants)} - #{a.name} - #{t.value}"
  end
end

RSpec.describe Fl::Framework::Access::Grant do
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

  let(:group1) do
    create(:actor_group, name: 'group1', actors: [ { actor: a1, title: 'a1' }, { actor: a2, title: 'a2' } ])
  end

  let(:gg1) do
    p = _ap::Read::NAME
    pm = _ap.permission_mask(p)
    Fl::Framework::Access::Grant.create(target: d40, granted_to: group1, grants: pm)
  end

  describe '#initialize' do
    it 'should initialize an invalid object with default arguments' do
      ng1 = Fl::Framework::Access::Grant.new

      expect(ng1.valid?).to eql(false)
      expect(ng1.errors.messages.keys).to include(:grants, :granted_to, :target)
    end

    it 'should initialize an invalid object with 0 permission mask' do
      ng1 = Fl::Framework::Access::Grant.new(target: d10, granted_to: a2)
      expect(ng1.valid?).to eql(false)
      expect(ng1.errors.messages.keys).to include(:grants)
    end

   it 'should initialize a valid object with valid arguments' do
     p = Fl::Framework::Access::Permission::Edit::NAME
     pm = Fl::Framework::Access::Permission.permission_mask(p)
     ng1 = Fl::Framework::Access::Grant.new(target: d10, granted_to: a2, grants: pm)

     expect(ng1.valid?).to eql(true)
     expect do
       ng1.save
     end.to change(Fl::Framework::Access::Grant, :count).by(1)
   end
  end

  describe 'create' do
    it 'should set the fingerprints' do
      p = Fl::Framework::Access::Permission::Edit::NAME
      pm = Fl::Framework::Access::Permission.permission_mask(p)
      ng1 = Fl::Framework::Access::Grant.new(target: d10, granted_to: a2, grants: pm)

     expect(ng1.valid?).to eql(true)
     expect(ng1.granted_to_fingerprint).to be_nil
     expect(ng1.target_fingerprint).to be_nil

     expect(ng1.save).to eql(true)
     expect(ng1.granted_to_fingerprint).to eql(a2.fingerprint)
     expect(ng1.target_fingerprint).to eql(d10.fingerprint)
   end
  end
  
  describe 'grant management' do
    let(:ng1) do
      p = _ap::Read::NAME
      pm = _ap.permission_mask(p)
      _ag.create(target: d10, granted_to: a2, grants: pm)
    end
    let(:ng2) do
      _ag.create(target: d10, granted_to: a3, grants: _ap::Read::BIT | 0x00110000)
    end
    
    context '#add_grant' do
      it 'should accept an integer' do
        expect(ng1.grants).to eql(_ap::Read::BIT)
        ng1.add_grant(0x00100000)
        expect(ng1.grants).to eql(_ap::Read::BIT | 0x00100000)
      end

      it 'should accept permission names' do
        expect(ng1.grants).to eql(_ap::Read::BIT)
        ng1.add_grant(_ap::Write::NAME)
        expect(ng1.grants).to eql(_ap::Read::BIT | _ap::Write::BIT)
      end

      it 'should accept an array argument' do
        expect(ng1.grants).to eql(_ap::Read::BIT)
        ng1.add_grant([ _ap::Write::NAME, _ap::Delete::NAME ])
        expect(ng1.grants).to eql(_ap::Read::BIT | _ap::Write::BIT | _ap::Delete::BIT)
      end
    end

    context '#remove_grant' do
      it 'should accept an integer' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        ng2.remove_grant(0x00100000)
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00010000)
      end

      it 'should accept permission names' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        ng2.remove_grant(_ap::Read::NAME)
        expect(ng2.grants).to eql(0x00110000)
      end

      it 'should accept an array argument' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        ng2.remove_grant([ _ap::Write::NAME, _ap::Read::NAME ])
        expect(ng2.grants).to eql(0x00110000)
      end
    end

    context '#has_grant?' do
      it 'should accept an integer' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        expect(ng2.has_grant?(0x00100000)).to eql(true)
        expect(ng2.has_grant?(0x00001000)).to eql(false)
      end

      it 'should accept permission names' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        expect(ng2.has_grant?(_ap::Read::NAME)).to eql(true)
      end

      it 'should accept an array argument' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        expect(ng2.has_grant?([ _ap::Write::NAME, _ap::Read::NAME ])).to eql(true)
      end
    end
    
    context '.add_grant' do
      it 'should accept an integer' do
        expect(ng1.grants).to eql(_ap::Read::BIT)
        expect(_ag.add_grant(0x00100000, ng1.granted_to, ng1.target).id).to eql(ng1.id)
        ng1.reload
        expect(ng1.grants).to eql(_ap::Read::BIT | 0x00100000)
      end

      it 'should accept permission names' do
        expect(ng1.grants).to eql(_ap::Read::BIT)
        expect(_ag.add_grant(_ap::Write::BIT, ng1.granted_to, ng1.target).id).to eql(ng1.id)
        ng1.reload
        expect(ng1.grants).to eql(_ap::Read::BIT | _ap::Write::BIT)
      end

      it 'should accept an array argument' do
        expect(ng1.grants).to eql(_ap::Read::BIT)
        expect(_ag.add_grant([ _ap::Write::NAME, _ap::Delete::NAME ],
                             ng1.granted_to, ng1.target).id).to eql(ng1.id)
        ng1.reload
        expect(ng1.grants).to eql(_ap::Read::BIT | _ap::Write::BIT | _ap::Delete::BIT)
      end

      it 'should create a new grant object if necessary' do
        g = _ag.add_grant([ _ap::Write::NAME, _ap::Delete::NAME ], a4, d10)
        expect(g).to be_a(_ag)
        expect(g.changed?).to eq(false)
        expect(g.grants).to eql(_ap::Write::BIT | _ap::Delete::BIT)
      end
    end

    context '.remove_grant' do
      it 'should accept an integer' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        _ag.remove_grant(0x00100000, ng2.granted_to, ng2.target)
        ng2.reload
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00010000)
      end

      it 'should accept permission names' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        _ag.remove_grant(_ap::Read::NAME, ng2.granted_to, ng2.target)
        ng2.reload
        expect(ng2.grants).to eql(0x00110000)
      end

      it 'should accept an array argument' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        _ag.remove_grant([ _ap::Write::NAME, _ap::Read::NAME ], ng2.granted_to, ng2.target)
        ng2.reload
        expect(ng2.grants).to eql(0x00110000)
      end

      it 'should handle undefined grants' do
        g = _ag.remove_grant([ _ap::Write::NAME, _ap::Read::NAME ], a4, d11)
        expect(g).to be_nil
      end

      it 'should delete a grant with empty permissions' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        gq = _ag.where('(id = :gid)', gid: ng2.id)
        expect(gq.count).to eql(1)
        
        _ag.remove_grant(_ap::Read::BIT | 0x00110000, ng2.granted_to, ng2.target)
        gq = _ag.where('(id = :gid)', gid: ng2.id)
        expect(gq.count).to eql(0)
      end
    end

    context '.has_grant?' do
      it 'should accept an integer' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        expect(_ag.has_grant?(0x00100000, ng2.granted_to, ng2.target)).to eql(true)
        expect(_ag.has_grant?(0x00001000, ng2.granted_to, ng2.target)).to eql(false)
      end

      it 'should accept permission names' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        expect(_ag.has_grant?(_ap::Read::NAME, ng2.granted_to, ng2.target)).to eql(true)
      end

      it 'should accept an array argument' do
        expect(ng2.grants).to eql(_ap::Read::BIT | 0x00110000)
        expect(_ag.has_grant?([ _ap::Write::NAME, _ap::Read::NAME ], ng2.granted_to, ng2.target)).to eql(true)
      end

      it 'should handle a missing grant' do
        expect(_ag.has_grant?(0x00010000, a4, d10)).to eq(false)
      end
    end

    context '.grants_for_actor' do
      it 'should return the correct value' do
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        xl = obj_fingerprints([ g1, g4 ]) | obj_fingerprints(actor_owner_grants(a2))
        expect(obj_fingerprints(_ag.grants_for_actor(a2))).to match_array(xl)

        xl = obj_fingerprints([ g2, g6 ]) | obj_fingerprints(actor_owner_grants(a3))
        expect(obj_fingerprints(_ag.grants_for_actor(a3))).to match_array(xl)
      end

      it 'should support fingerprints' do
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        xl = obj_fingerprints([ g5, g7, g9, g10 ]) | obj_fingerprints(actor_owner_grants(a4))
        expect(obj_fingerprints(_ag.grants_for_actor(a4.fingerprint))).to match_array(xl)
      end
    end

    context '.grants_for_target' do
      it 'should return the correct value' do
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        xl = obj_fingerprints([ g1, g2 ]) | obj_fingerprints(target_owner_grants(d10))
        expect(obj_fingerprints(_ag.grants_for_target(d10))).to match_array(xl)

        xl = obj_fingerprints([ g4, g5 ]) | obj_fingerprints(target_owner_grants(d20))
        expect(obj_fingerprints(_ag.grants_for_target(d20))).to match_array(xl)
      end

      it 'should support fingerprints' do
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        xl = obj_fingerprints([ g6, g7 ]) | obj_fingerprints(target_owner_grants(d21))
        expect(obj_fingerprints(_ag.grants_for_target(d21.fingerprint))).to match_array(xl)
      end
    end

    context '.delete_grants_for_actor' do
      it 'should delete the correct grants' do
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        ac = actor_owner_grants(a2).count + 2
        r = _ag.delete_grants_for_actor(a2)
        expect(r.cmd_status).to eql("DELETE #{ac}") if r.is_a?(PG::Result)
        expect(actor_owner_grants(a2).count).to eql(0)

        ac = actor_owner_grants(a3).count + 2
        r = _ag.delete_grants_for_actor(a3)
        expect(r.cmd_status).to eql("DELETE #{ac}") if r.is_a?(PG::Result)
        expect(actor_owner_grants(a2).count).to eql(0)
      end

      it 'should support fingerprints' do
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        ac = actor_owner_grants(a4).count + 4
        r = _ag.delete_grants_for_actor(a4.fingerprint)
        expect(r.cmd_status).to eql("DELETE #{ac}") if r.is_a?(PG::Result)
        expect(actor_owner_grants(a4).count).to eql(0)
      end

      it 'should be a no-op with invalid input' do
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        expect(_ag.delete_grants_for_actor(10)).to be_nil
      end
    end

    context '.delete_grants_for_target' do
      it 'should delete the correct grants' do
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        ac = target_owner_grants(d10).count + 2
        r = _ag.delete_grants_for_target(d10)
        expect(r.cmd_status).to eql("DELETE #{ac}") if r.is_a?(PG::Result)
        expect(target_owner_grants(d10).count).to eql(0)

        ac = target_owner_grants(d20).count + 2
        r = _ag.delete_grants_for_target(d20)
        expect(r.cmd_status).to eql("DELETE #{ac}") if r.is_a?(PG::Result)
        expect(target_owner_grants(d20).count).to eql(0)
      end

      it 'should support fingerprints' do
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        ac = target_owner_grants(d21).count + 2
        r = _ag.delete_grants_for_target(d21)
        expect(r.cmd_status).to eql("DELETE #{ac}") if r.is_a?(PG::Result)
        expect(target_owner_grants(d21).count).to eql(0)
      end

      it 'should be a no-op with invalid input' do
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        expect(_ag.delete_grants_for_target(10)).to be_nil
      end
    end
  end

  describe "#to_hash" do
    it "should track :verbosity" do
      id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
      h = g1.to_hash(a1, { verbosity: :id })
      expect(h.keys).to match_array(id_keys)

      ignore_keys = id_keys | [ ]
      h = g1.to_hash(a1, { verbosity: :ignore })
      expect(h.keys).to match_array(ignore_keys)

      minimal_keys = id_keys | [ :grants, :granted_to, :target, :created_at, :updated_at ]
      h = g1.to_hash(a1, { verbosity: :minimal })
      expect(h.keys).to match_array(minimal_keys)

      standard_keys = minimal_keys | [ ]
      h = g1.to_hash(a1, { verbosity: :standard })
      expect(h.keys).to match_array(standard_keys)

      verbose_keys = standard_keys | [ ]
      h = g1.to_hash(a1, { verbosity: :verbose })
      expect(h.keys).to match_array(verbose_keys)

      complete_keys = verbose_keys | [ ]
      h = g1.to_hash(a1, { verbosity: :complete })
      expect(h.keys).to match_array(complete_keys)
    end

    it "should customize key lists" do
      id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
      h_keys = id_keys | [ :grants ]
      h = g1.to_hash(a1, { verbosity: :id, include: [ :grants ] })
      expect(h.keys).to match_array(h_keys)

      minimal_keys = id_keys | [ :grants, :granted_to, :target, :created_at, :updated_at ]
      h_keys = minimal_keys - [ :granted_to, :target ]
      h = g1.to_hash(a1, { verbosity: :minimal, except: [ :granted_to, :target ] })
      expect(h.keys).to match_array(h_keys)
    end

    it "should customize key lists for subobjects" do
      id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]

      to_keys = id_keys + [ :name, :created_at, :updated_at ]
      tg_keys = id_keys + [ :permissions, :title, :value, :created_at, :updated_at ]
      h = g1.to_hash(a1, { verbosity: :minimal })
      expect(h[:granted_to].keys).to match_array(to_keys)
      expect(h[:target].keys).to match_array(tg_keys)

      to_keys = id_keys + [ :name ]
      tg_keys = id_keys + [ :title ]
      h = g1.to_hash(a1, {
                       verbosity: :minimal,
                       to_hash: {
                         target: { verbosity: :id, include: :title },
                         granted_to: { verbosity: :id, include: [ :name ] }
                       }
                     })
      expect(h[:granted_to].keys).to match_array(to_keys)
      expect(h[:target].keys).to match_array(tg_keys)
    end

    it "should return correct permissions for target" do
      h = g1.to_hash(a1, { verbosity: :minimal })
      t = h[:target]
      expect(t[:permissions]).to include({ read: true, write: true, delete: true, index: true })

      h = g1.to_hash(a2, { verbosity: :minimal })
      t = h[:target]
      expect(t[:permissions]).to include({ read: false, write: true, delete: false, index: false })
    end
  end
  
  describe '.build_query' do
    it 'should return all grants with default options' do
      # trigger the data and grant creation
      ogl = obj_fingerprints(target_owner_grants([ d10, d11, d20, d21, d12, d30, d40 ]))
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]
      
      q = Fl::Framework::Access::Grant.build_query()
      expect(obj_fingerprints(q)).to match_array(ogl | obj_fingerprints(gl))
    end

    it 'should support :only_granted_to and :except_granted_to' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]
      
      xl = obj_fingerprints([ g2, g6 ]) | obj_fingerprints(target_owner_grants([ d30, d40 ]))
      q = Fl::Framework::Access::Grant.build_query(only_granted_to: a3)
      expect(obj_fingerprints(q)).to match_array(xl)
      q = Fl::Framework::Access::Grant.build_query(only_granted_to: a3.fingerprint)
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g2, g5, g6, g7, g9, g10 ]) \
           | obj_fingerprints(target_owner_grants([ d30, d40 ]))
      q = Fl::Framework::Access::Grant.build_query(only_granted_to: [ a3.fingerprint, a4 ])
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g1, g3, g4, g5, g7, g8, g9, g10 ]) \
           | obj_fingerprints(target_owner_grants([ d10, d11, d110, d12, d20, d21, d22 ]))
      q = Fl::Framework::Access::Grant.build_query(except_granted_to: a3)
      expect(obj_fingerprints(q)).to match_array(xl)
      q = Fl::Framework::Access::Grant.build_query(except_granted_to: a3.fingerprint)
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g1, g3, g4, g8 ]) \
           | obj_fingerprints(target_owner_grants([ d10, d11, d110, d12, d20, d21, d22 ]))
      q = Fl::Framework::Access::Grant.build_query(except_granted_to: [ a3.fingerprint, a4 ])
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g5, g7, g9, g10 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = Fl::Framework::Access::Grant.build_query(only_granted_to: [ a3.fingerprint, a4 ],
                                                   except_granted_to: a3.fingerprint)
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ ]) | obj_fingerprints(target_owner_grants([ ]))
      q = Fl::Framework::Access::Grant.build_query(only_granted_to: [ a1.fingerprint ],
                                                   except_granted_to: a1.fingerprint)
      expect(obj_fingerprints(q)).to match_array(xl)
    end

    it 'should support :only_targets and :except_targets' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]
      
      xl = obj_fingerprints([ g1, g2 ]) | obj_fingerprints(target_owner_grants(d10))
      q = Fl::Framework::Access::Grant.build_query(only_targets: d10)
      expect(obj_fingerprints(q)).to match_array(xl)
      q = Fl::Framework::Access::Grant.build_query(only_targets: d10.fingerprint)
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g1, g2, g6, g7 ]) | obj_fingerprints(target_owner_grants([ d10, d21 ]))
      q = Fl::Framework::Access::Grant.build_query(only_targets: [ d10.fingerprint, d21 ])
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g3, g4, g5, g6, g7, g8, g9, g10 ]) \
           | obj_fingerprints(target_owner_grants([ d11, d110, d20, d21, d22, d12, d30, d40 ]))
      q = Fl::Framework::Access::Grant.build_query(except_targets: d10)
      expect(obj_fingerprints(q)).to match_array(xl)
      q = Fl::Framework::Access::Grant.build_query(except_targets: d10.fingerprint)
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g3, g4, g5, g8, g10 ]) \
           | obj_fingerprints(target_owner_grants([ d11, d110, d20, d22, d12, d40 ]))
      q = Fl::Framework::Access::Grant.build_query(except_targets: [ d10.fingerprint, d21, d30 ])
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g6, g7 ]) | obj_fingerprints(target_owner_grants([ d21 ]))
      q = Fl::Framework::Access::Grant.build_query(only_targets: [ d10.fingerprint, d21 ],
                                                   except_targets: d10.fingerprint)
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ ]) | obj_fingerprints(target_owner_grants([ ]))
      q = Fl::Framework::Access::Grant.build_query(only_targets: [ d10.fingerprint ],
                                                   except_targets: d10.fingerprint)
      expect(obj_fingerprints(q)).to match_array(xl)
    end

    context 'with :permissions' do
      it 'should support a scalar value' do
        # trigger the data and grant creation
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        m = _ap.permission_mask(_ap::Write::NAME)
        q = _ag.build_query(permissions: m)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g3, g5, g8, g9 ]))

        m = _ap.permission_mask(_ap::Write::NAME) | _ap.permission_mask(_ap::Read::NAME)
        q = _ag.build_query(permissions: m)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        m = _ap.permission_mask(_ap::Edit::NAME)
        q = _ag.build_query(permissions: m)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        m = _ap.permission_mask(_ap::Manage::NAME)
        q = _ag.build_query(permissions: m)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g9 ]))
      end

      it 'should accept various input types for scalar values' do
        # trigger the data and grant creation
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        q = _ag.build_query(permissions: _ap::Write::NAME)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g3, g5, g8, g9 ]))

        q = _ag.build_query(permissions: _ap::Write::BIT)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g3, g5, g8, g9 ]))

        q = _ag.build_query(permissions: _ap::Write)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g3, g5, g8, g9 ]))

        q = _ag.build_query(permissions: _ap::Write::BIT | _ap::Read::BIT)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: [ _ap::Write, _ap::Read::NAME ])
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: [ _ap::Write::BIT, _ap::Read ])
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: _ap::Edit::NAME)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: _ap::Edit)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: [ _ap::Edit ])
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: _ap::Manage::NAME)
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g9 ]))

        q = _ag.build_query(permissions: [ _ap::Manage ])
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g9 ]))
      end

      it 'should support a single :all value' do
        # trigger the data and grant creation
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        m = _ap.permission_mask(_ap::Write::NAME)
        q = _ag.build_query(permissions: { all: m })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g3, g5, g8, g9 ]))

        m = _ap.permission_mask(_ap::Write::NAME) | _ap.permission_mask(_ap::Read::NAME)
        q = _ag.build_query(permissions: { all: m })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        m = _ap.permission_mask(_ap::Edit::NAME)
        q = _ag.build_query(permissions: { all: m })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        m = _ap.permission_mask(_ap::Manage::NAME)
        q = _ag.build_query(permissions: { all: m })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g9 ]))
      end

      it 'should accept various input types for :all values' do
        # trigger the data and grant creation
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        q = _ag.build_query(permissions: { all: _ap::Write::NAME })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g3, g5, g8, g9 ]))

        q = _ag.build_query(permissions: { all: _ap::Write::BIT })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g3, g5, g8, g9 ]))

        q = _ag.build_query(permissions: { all: _ap::Write })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g3, g5, g8, g9 ]))

        q = _ag.build_query(permissions: { all: _ap::Write::BIT | _ap::Read::BIT })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: { all: [ _ap::Write, _ap::Read::NAME ] })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: { all: [ _ap::Write::BIT, _ap::Read ] })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: { all: _ap::Edit::NAME })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: { all: _ap::Edit })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: { all: [ _ap::Edit ] })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))

        q = _ag.build_query(permissions: { all: _ap::Manage::NAME })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g9 ]))

        q = _ag.build_query(permissions: { all: [ _ap::Manage ] })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g9 ]))
      end

      it 'should support a single :any value' do
        # trigger the data and grant creation
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        m = _ap.permission_mask(_ap::Write::NAME)
        q = _ag.build_query(permissions: { any: m })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g3, g5, g8, g9 ]))

        m = _ap.permission_mask(_ap::Write::NAME) | _ap.permission_mask(_ap::Read::NAME)
        q = _ag.build_query(permissions: { any: m })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]))

        m = _ap.permission_mask(_ap::Edit::NAME)
        q = _ag.build_query(permissions: { any: m })
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]))
      end

      it 'should accept various input types for :any values' do
        # trigger the data and grant creation
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        q = _ag.build_query(permissions: { any: _ap::Write })
        xl = obj_fingerprints([ g1, g3, g5, g8, g9 ])
        expect(obj_fingerprints(q)).to match_array(xl)

        q = _ag.build_query(permissions: { any: _ap::Write::BIT | _ap::Read::BIT })
        xl = obj_fingerprints([ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ])
        expect(obj_fingerprints(q)).to match_array(xl)

        q = _ag.build_query(permissions: { any: [ _ap::Write::BIT, _ap::Read::BIT ] })
        xl = obj_fingerprints([ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ])
        expect(obj_fingerprints(q)).to match_array(xl)

        q = _ag.build_query(permissions: { any: [ _ap::Write, _ap::Read ] })
        xl = obj_fingerprints([ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ])
        expect(obj_fingerprints(q)).to match_array(xl)
      end

      it 'should support simple array values' do
        # trigger the data and grant creation
        dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
        gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

        m = _ap.permission_mask(_ap::Write::NAME)
        xl = obj_fingerprints([ g1, g3, g5, g8, g9 ]) | obj_fingerprints(target_owner_grants(nil))
        q = _ag.build_query(permissions: [ { all: m }, :or, { all: _ap::Owner } ])
        expect(obj_fingerprints(q)).to match_array(xl)

        # This should really be done with a single any: parameter
        q = _ag.build_query(permissions: [ { all: _ap::Write }, :or, { all: _ap::Read::NAME } ])
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g1, g2, g3, g4, g5, g6, g7, g8,
                                                                      g9, g10 ]))

        # And this should really be done with a single all: parameter
        q = _ag.build_query(permissions: [ { all: _ap::Write }, :and, { all: _ap::Read::NAME } ])
        expect(obj_fingerprints(q)).to match_array(obj_fingerprints([ g3, g5, g9 ]))
      end
    end

    it 'should support :only_types and :except_types' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]
      
      xl = obj_fingerprints([ g1, g2, g3, g8 ]) \
           | obj_fingerprints(target_owner_grants([ d10, d11, d110, d12 ]))
      q = Fl::Framework::Access::Grant.build_query(only_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)
      q = Fl::Framework::Access::Grant.build_query(only_types: TestDatumOne.name)
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g1, g2, g3, g4, g5, g6, g7, g8 ]) \
           | obj_fingerprints(target_owner_grants([ d10, d11, d110, d12, d20, d21, d22 ]))
      q = Fl::Framework::Access::Grant.build_query(only_types: [ TestDatumOne, TestDatumTwo ])
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g4, g5, g6, g7, g9, g10 ]) \
           | obj_fingerprints(target_owner_grants([ d20, d21, d22, d30, d40 ]))
      q = Fl::Framework::Access::Grant.build_query(except_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)
      q = Fl::Framework::Access::Grant.build_query(except_types: TestDatumOne.name)
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g4, g5, g6, g7, g10 ]) \
           | obj_fingerprints(target_owner_grants([ d20, d21, d22, d40 ]))
      q = Fl::Framework::Access::Grant.build_query(except_types: [ TestDatumOne, TestDatumThree ])
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g9, g10 ]) | obj_fingerprints(target_owner_grants([ d30, d40 ]))
      q = Fl::Framework::Access::Grant.build_query(except_types: [ TestDatumOne, TestDatumTwo ])
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g4, g5, g6, g7 ]) | obj_fingerprints(target_owner_grants([ d20, d21, d22 ]))
      q = Fl::Framework::Access::Grant.build_query(only_types: [ TestDatumOne, TestDatumTwo ],
                                                   except_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ ]) | obj_fingerprints(target_owner_grants([ ]))
      q = Fl::Framework::Access::Grant.build_query(only_types: [ TestDatumOne ],
                                                   except_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(q)).to match_array(xl)
    end

    it 'should support selector combinations' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]
      
      xl = obj_fingerprints([ g2 ])
      q = Fl::Framework::Access::Grant.build_query(only_targets: d10, only_granted_to: a3)
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g1 ]) | obj_fingerprints(target_owner_grants([ d10 ]))
      q = Fl::Framework::Access::Grant.build_query(only_targets: d10, except_granted_to: a3)
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g3, g8 ]) | obj_fingerprints(target_owner_grants([ d20, d22 ]))
      q = Fl::Framework::Access::Grant.build_query(except_targets: [ d10.fingerprint, d21 ],
                                                   only_granted_to: a1)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g3, g8 ])
      q = Fl::Framework::Access::Grant.build_query(except_targets: [ d10.fingerprint, d21 ],
                                                   only_granted_to: a1,
                                                   only_types: TestDatumOne)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints(target_owner_grants([ d20, d22 ]))
      q = Fl::Framework::Access::Grant.build_query(except_targets: [ d10.fingerprint, d21 ],
                                                   only_granted_to: a1,
                                                   except_types: TestDatumOne)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g5, g9, g10 ]) | obj_fingerprints(target_owner_grants([ d30, d40 ]))
      q = Fl::Framework::Access::Grant.build_query(except_targets: [ d10.fingerprint, d21 ],
                                                   except_granted_to: [ a1, a2 ])
      expect(obj_fingerprints(q)).to match_array(xl)

      m = _ap.permission_mask(_ap::Read::NAME)
      xl = obj_fingerprints([ g3, g4, g5, g9, g10 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = Fl::Framework::Access::Grant.build_query(except_targets: [ d10.fingerprint, d21 ],
                                                   permissions: m)
      expect(obj_fingerprints(q)).to match_array(xl)

      m = _ap::Read
      xl = obj_fingerprints([ g4, g5, g9, g10 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = Fl::Framework::Access::Grant.build_query(except_targets: [ d10.fingerprint, d21 ],
                                                   permissions: { all: m },
                                                   except_granted_to: a1)
      expect(obj_fingerprints(q)).to match_array(xl)

      m = _ap::Edit::NAME
      xl = obj_fingerprints([ g3, g5, g9 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = Fl::Framework::Access::Grant.build_query(except_targets: [ d10.fingerprint, d21 ],
                                                   permissions: m)
      expect(obj_fingerprints(q)).to match_array(xl)

      m = _ap::Edit
      xl = obj_fingerprints([ g5, g9 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = Fl::Framework::Access::Grant.build_query(except_targets: [ d10.fingerprint, d21 ],
                                                   permissions: { all: m },
                                                   except_granted_to: a1)
      expect(obj_fingerprints(q)).to match_array(xl)
    end

    it 'should support order and pagination options' do
      # this statement triggers the grant creation
      xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]
      
      q = _ag.build_query(order: 'id', permissions: { any: _ap::Edit })
      expect(obj_fingerprints(q)).to eql(obj_fingerprints(xl))

      q = _ag.build_query(order: 'id DESC', permissions: { any: _ap::Edit })
      expect(obj_fingerprints(q)).to eql(obj_fingerprints(xl).reverse)
      
      q = _ag.build_query(order: 'id', offset: 2, limit: 2, permissions: { any: _ap::Edit })
      expect(obj_fingerprints(q)).to eql(obj_fingerprints([ g3, g4 ]))
    end
  end
  
  describe '.accessible_query' do
    it 'should return grants correctly' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = obj_fingerprints([ g3 ]) | obj_fingerprints(target_owner_grants([ d10, d20, d22 ]))
      q = _ag.accessible_query(a1, _ap::Read)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g5, g7, g9, g10 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Read::BIT)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g5, g9 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Write)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g5, g9 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Edit)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g1, g4 ]) | obj_fingerprints(target_owner_grants([ d11, d110, d12, d21 ]))
      q = _ag.accessible_query(a2, nil)
      expect(obj_fingerprints(q)).to match_array(xl)

      # [ _ap::Read, _ap::Write ] expands to the OR of the bit values, and that is passed to :all,
      # so only targets with both read and write permission are returned. There are none (except for
      # those owned by a2)
      
      xl = obj_fingerprints([ ]) | obj_fingerprints(target_owner_grants([ d11, d110, d12, d21 ]))
      q = _ag.accessible_query(a2, [ _ap::Read, _ap::Write ])
      expect(obj_fingerprints(q)).to match_array(xl)

      # see above
      
      xl = [ ] | obj_fingerprints(target_owner_grants([ d11, d110, d12, d21 ]))
      q = _ag.accessible_query(a2, [ _ap::Edit ])
      expect(obj_fingerprints(q)).to match_array(xl)
      
      xl = obj_fingerprints([ g5, g9 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, [ _ap::Read, _ap::Write ])
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g5, g9 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, [ _ap::Edit ])
      expect(obj_fingerprints(q)).to match_array(xl)
    end

    it 'should support filtering by type' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = obj_fingerprints([ g1 ]) | obj_fingerprints(target_owner_grants([ d11, d110, d12 ]))
      q = _ag.accessible_query(a2, nil, only_types: TestDatumOne)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g4 ]) | obj_fingerprints(target_owner_grants([ d21 ]))
      q = _ag.accessible_query(a2, nil, only_types: TestDatumTwo, order: 'id')
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g9 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Read, only_types: [ TestDatumOne, TestDatumThree ], order: 'id')
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g5, g7, g9 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Read, only_types: [ TestDatumTwo, TestDatumThree ], order: 'id')
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ g9 ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Write, except_types: [ TestDatumTwo ], order: 'id')
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ ]) | obj_fingerprints(target_owner_grants([ d21 ]))
      q = _ag.accessible_query(a2, [ _ap::Read, _ap::Write ], only_types: TestDatumTwo, order: 'id')
      expect(obj_fingerprints(q)).to match_array(xl)
    end
    
    it 'should support order and pagination options' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = (obj_fingerprints([ g1 ]) | obj_fingerprints(target_owner_grants([ d11, d110, d12 ]))).sort
      q = _ag.accessible_query(a2, nil, only_types: TestDatumOne, order: 'id')
      expect(obj_fingerprints(q)).to eql(xl)

      xl = (obj_fingerprints([ g1 ]) | obj_fingerprints(target_owner_grants([ d11, d110, d12 ]))).sort.reverse
      q = _ag.accessible_query(a2, nil, only_types: TestDatumOne, order: 'id DESC')
      expect(obj_fingerprints(q)).to eql(xl)

      xl = (obj_fingerprints([ g1 ]) | obj_fingerprints(target_owner_grants([ d11, d110, d12 ]))).sort.slice(1..2)
      q = _ag.accessible_query(a2, nil, only_types: TestDatumOne, order: 'id', offset: 1, limit: 2)
      expect(obj_fingerprints(q)).to eql(xl)
    end

    it 'should support multiple actors' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]
      ggl = [ gg1 ]

      xl = obj_fingerprints([ g3, gg1 ]) | obj_fingerprints(target_owner_grants([ d10, d20, d22 ]))
      q = _ag.accessible_query([ a1, group1 ], _ap::Read)
      expect(obj_fingerprints(q)).to match_array(xl)
    end

    it 'should return an empty set with invalid actors' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]
      ggl = [ gg1 ]

      xl = obj_fingerprints([ ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(nil, _ap::Read)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query(1234, _ap::Read)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query([ nil, a1 ], _ap::Read)
      expect(obj_fingerprints(q)).to match_array(xl)

      xl = obj_fingerprints([ ]) | obj_fingerprints(target_owner_grants([ ]))
      q = _ag.accessible_query([ a1, 1234 ], _ap::Read)
      expect(obj_fingerprints(q)).to match_array(xl)
    end
  end
end
