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

def data_grants(dl)
  Fl::Framework::Asset::AccessGrant.build_query(only_data: dl).all
end

def owner_grants(dl)
  Fl::Framework::Asset::AccessGrant.build_query(only_data: dl, only_permissions: Fl::Framework::Asset::Permission::Owner::NAME).all
end

def pp_grants(gl)
  gl.map { |g| [ g.permission, g.actor.name, g.data_object.value ] }
end

RSpec.describe Fl::Framework::Asset::AccessGrant do
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
                                             permission: Fl::Framework::Access::Permission::Edit::NAME)
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

  context '#initialize' do
    it 'should initialize an invalid object with default arguments' do
      ng1 = Fl::Framework::Asset::AccessGrant.new

      expect(ng1.valid?).to eql(false)
      expect(ng1.errors.messages.keys).to include(:permission, :actor, :asset)
    end

    it 'should initialize an invalid object with unknown permission' do
      ng1 = Fl::Framework::Asset::AccessGrant.new(asset: d10.asset_record, actor: a2, permission: :unknown)

      expect(ng1.valid?).to eql(false)
      expect(ng1.errors.messages.keys).to include(:permission)
    end

   it 'should initialize a valid object with valid arguments' do
     p = Fl::Framework::Access::Permission::Write::NAME
     ng1 = Fl::Framework::Asset::AccessGrant.new(asset: d10.asset_record, actor: a2, permission: p)
     expect(ng1.valid?).to eql(true)
     expect do
       ng1.save
     end.to change(Fl::Framework::Asset::AccessGrant, :count).by(1)

     p = Fl::Framework::Access::Permission.lookup(Fl::Framework::Access::Permission::Write::NAME)
     ng2 = Fl::Framework::Asset::AccessGrant.new(asset: d10.asset_record, actor: a3, permission: p)
     expect(ng2.valid?).to eql(true)
     expect do
       ng2.save
     end.to change(Fl::Framework::Asset::AccessGrant, :count).by(1)

     p = Fl::Framework::Access::Permission::Write
     ng3 = Fl::Framework::Asset::AccessGrant.new(asset: d10.asset_record, actor: a4, permission: p)
     expect(ng3.valid?).to eql(true)
     expect do
       ng3.save
     end.to change(Fl::Framework::Asset::AccessGrant, :count).by(1)
   end
  end

  context 'create' do
    it 'should set the :data_object association on create' do
     ng1 = Fl::Framework::Asset::AccessGrant.new(asset: d10.asset_record, actor: a2,
                                                 permission: Fl::Framework::Access::Permission::Write::NAME)

     expect(ng1.valid?).to eql(true)
     expect(ng1.data_object).to be_nil
     expect(ng1.save).to eql(true)
     expect(ng1.data_object).to be_a(d10.class)
     expect(ng1.data_object.fingerprint).to eql(d10.fingerprint)
   end
  end

  context "#to_hash" do
    it "should track :verbosity" do
      ng1 = Fl::Framework::Asset::AccessGrant.new(asset: d10.asset_record, actor: a2,
                                                  permission: Fl::Framework::Access::Permission::Write::NAME)
      expect(ng1.save).to eql(true)

      id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
      h = ng1.to_hash(a1, { verbosity: :id })
      expect(h.keys).to match_array(id_keys)

      ignore_keys = id_keys | [ ]
      h = ng1.to_hash(a1, { verbosity: :ignore })
      expect(h.keys).to match_array(ignore_keys)

      minimal_keys = id_keys | [ :permission, :actor, :asset, :created_at, :updated_at ]
      h = ng1.to_hash(a1, { verbosity: :minimal })
      expect(h.keys).to match_array(minimal_keys)

      standard_keys = minimal_keys | [ ]
      h = ng1.to_hash(a1, { verbosity: :standard })
      expect(h.keys).to match_array(standard_keys)

      verbose_keys = standard_keys | [ :data_object ]
      h = ng1.to_hash(a1, { verbosity: :verbose })
      expect(h.keys).to match_array(verbose_keys)

      complete_keys = verbose_keys | [ ]
      h = ng1.to_hash(a1, { verbosity: :complete })
      expect(h.keys).to match_array(complete_keys)
    end

    it "should customize key lists" do
      ng1 = Fl::Framework::Asset::AccessGrant.new(asset: d10.asset_record, actor: a2,
                                                 permission: Fl::Framework::Access::Permission::Write::NAME)
      expect(ng1.save).to eql(true)

      id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
      h_keys = id_keys | [ :permission ]
      h = ng1.to_hash(a1, { verbosity: :id, include: [ :permission ] })
      expect(h.keys).to match_array(h_keys)

      minimal_keys = id_keys | [ :permission, :actor, :asset, :created_at, :updated_at ]
      h_keys = minimal_keys - [ :actor, :asset ]
      h = ng1.to_hash(a1, { verbosity: :minimal, except: [ :actor, :asset ] })
      expect(h.keys).to match_array(h_keys)
    end

    it "should customize key lists for subobjects" do
      ng1 = Fl::Framework::Asset::AccessGrant.new(asset: d10.asset_record, actor: a2,
                                                 permission: Fl::Framework::Access::Permission::Write::NAME)

      expect(ng1.save).to eql(true)

      id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
      h = ng1.to_hash(a1, { verbosity: :minimal, include: [ :data_object ] })
      a_keys = id_keys + [ :asset, :owner, :created_at, :updated_at ]
      d_keys = id_keys + [ :title, :value, :permissions, :created_at, :updated_at ]
      expect(h[:asset].keys).to match_array(a_keys)
      expect(h[:data_object].keys).to match_array(d_keys)

      h = ng1.to_hash(a1, {
                       verbosity: :minimal,
                       include: [ :data_object ],
                       to_hash: {
                         asset: { verbosity: :id, include: :owner },
                         data_object: { verbosity: :id, include: [ :value ] }
                       }
                     })
      a_keys = id_keys + [ :owner ]
      d_keys = id_keys + [ :value ]
      expect(h[:asset].keys).to match_array(a_keys)
      expect(h[:data_object].keys).to match_array(d_keys)
    end
  end
  
  context '.build_query' do
    it 'should return all grants with default options' do
      # trigger the data and grant creation
      ogl = owner_grants([ d10, d11, d20, d21, d12 ])
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]
      
      q = Fl::Framework::Asset::AccessGrant.build_query()
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(ogl | gl))
    end

    it 'should support :only_actors and :except_actors' do
      # trigger the data and grant creation
      ogl = owner_grants([ d10, d11, d20, d21, d12 ])
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]
      
      xl = [ g3, g8 ] | owner_grants([ d10, d20 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_actors: a1)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      q = Fl::Framework::Asset::AccessGrant.build_query(only_actors: a1.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g3, g5, g7, g8 ] | owner_grants([ d10, d20 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_actors: [ a1.fingerprint, a4 ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g1, g2, g4, g5, g6, g7 ] | owner_grants([ d11, d12, d21 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_actors: a1)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      q = Fl::Framework::Asset::AccessGrant.build_query(except_actors: a1.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g1, g2, g4, g6 ] | owner_grants([ d11, d12, d21 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_actors: [ a1.fingerprint, a4 ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g5, g7 ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_actors: [ a1.fingerprint, a4 ],
                                                        except_actors: a1.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_actors: [ a1.fingerprint ],
                                                        except_actors: a1.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
    end

    it 'should support :only_data and :except_data' do
      # trigger the data and grant creation
      ogl = owner_grants([ d10, d11, d20, d21, d12 ])
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]
      
      xl = [ g1, g2 ] | owner_grants([ d10 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_data: d10)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      q = Fl::Framework::Asset::AccessGrant.build_query(only_data: d10.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g1, g2, g6, g7 ] | owner_grants([ d10, d21 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_data: [ d10.fingerprint, d21 ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g3, g4, g5, g6, g7, g8 ] | owner_grants([ d11, d20, d21, d12 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_data: d10)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      q = Fl::Framework::Asset::AccessGrant.build_query(except_data: d10.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g3, g4, g5, g8 ] | owner_grants([ d11, d20, d12 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_data: [ d10.fingerprint, d21 ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g6, g7 ] | owner_grants([ d21 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_data: [ d10.fingerprint, d21 ],
                                                        except_data: d10.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_data: [ d10.fingerprint ],
                                                        except_data: d10.fingerprint)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
    end

    it 'should support :only_permissions and :except_permissions' do
      # trigger the data and grant creation
      ogl = owner_grants([ d10, d11, d20, d21, d12 ])
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]
      
      q = Fl::Framework::Asset::AccessGrant.build_query(only_permissions: Fl::Framework::Access::Permission::Write::NAME)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ g1 ].reverse))

      q = Fl::Framework::Asset::AccessGrant.build_query(only_permissions: Fl::Framework::Access::Permission::Write::NAME.to_s)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1 ]))

      q = Fl::Framework::Asset::AccessGrant.build_query(only_permissions: Fl::Framework::Access::Permission::Write)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1 ]))

      p = Fl::Framework::Access::Permission.lookup(Fl::Framework::Access::Permission::Write::NAME)
      q = Fl::Framework::Asset::AccessGrant.build_query(only_permissions: p)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1 ]))

      q = Fl::Framework::Asset::AccessGrant.build_query(only_permissions: [
                                                          Fl::Framework::Access::Permission::Write::NAME,
                                                          Fl::Framework::Access::Permission::Edit ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1, g3, g5, g8 ]))

      q = Fl::Framework::Asset::AccessGrant.build_query(except_permissions: Fl::Framework::Access::Permission::Edit)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1, g2, g4, g6, g7 ] | ogl))

      q = Fl::Framework::Asset::AccessGrant.build_query(except_permissions: [
                                                          Fl::Framework::Access::Permission::Write::NAME,
                                                          Fl::Framework::Access::Permission::Edit ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g2, g4, g6, g7 ] | ogl))

      q = Fl::Framework::Asset::AccessGrant.build_query(only_permissions: [
                                                          Fl::Framework::Access::Permission::Write::NAME,
                                                          Fl::Framework::Access::Permission::Edit
                                                        ],
                                                        except_permissions: Fl::Framework::Access::Permission::Edit)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ g1 ]))

      q = Fl::Framework::Asset::AccessGrant.build_query(only_permissions: [
                                                          Fl::Framework::Access::Permission::Edit::NAME
                                                        ],
                                                        except_permissions: [
                                                          Fl::Framework::Access::Permission::Edit
                                                        ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints([ ]))
    end

    it 'should support :only_types and :except_types' do
      # trigger the data and grant creation
      ogl = owner_grants([ d10, d11, d20, d21, d12 ])
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]
      
      xl = [ g1, g2, g3, g8 ] | owner_grants([ d10, d11, d12 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      q = Fl::Framework::Asset::AccessGrant.build_query(only_types: TestDatumOne.name)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = ogl | gl
      q = Fl::Framework::Asset::AccessGrant.build_query(only_types: [ TestDatumOne, TestDatumTwo ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g4, g5, g6, g7 ] | owner_grants([ d20, d21 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      q = Fl::Framework::Asset::AccessGrant.build_query(except_types: TestDatumOne.name)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      q = Fl::Framework::Asset::AccessGrant.build_query(except_types: [ TestDatumOne, TestDatumThree ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_types: [ TestDatumOne, TestDatumTwo ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g4, g5, g6, g7 ] | owner_grants([ d20, d21 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_types: [ TestDatumOne, TestDatumTwo ],
                                                        except_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_types: [ TestDatumOne ],
                                                        except_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
    end

    it 'should support :only_ and :except_ combinations' do
      # trigger the data and grant creation
      ogl = owner_grants([ d10, d11, d20, d21, d12 ])
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]
      
      xl = [ g2 ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_data: d10, only_actors: a3)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g1 ] | owner_grants([ d10 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(only_data: d10, except_actors: a3)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g3, g8 ] | owner_grants([ d20 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_data: [ d10.fingerprint, d21 ],
                                                        only_actors: a1)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ g3, g8 ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_data: [ d10.fingerprint, d21 ],
                                                        only_actors: a1,
                                                        only_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ ] | owner_grants([ d20 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_data: [ d10.fingerprint, d21 ],
                                                        only_actors: a1,
                                                        except_types: TestDatumOne)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ g5 ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_data: [ d10.fingerprint, d21 ],
                                                        except_actors: [ a1, a2 ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ ] | owner_grants([ d20 ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_data: [ d10.fingerprint, d21 ],
                                                        only_actors: a1,
                                                        only_permissions: Fl::Framework::Asset::Permission::Owner)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
      
      xl = [ g3, g8 ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.build_query(except_data: [ d10.fingerprint, d21 ],
                                                        only_actors: a1,
                                                        except_permissions: Fl::Framework::Asset::Permission::Owner)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
    end

    it 'should support order and pagination options' do
      # this statement triggers the grant creation
      xl = [ g1, g2, g3, g4, g5, g6, g7, g8 ].reverse
      
      q = Fl::Framework::Asset::AccessGrant.build_query(order: 'id',
                                                        except_permissions: Fl::Framework::Asset::Permission::Owner)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ g1, g2, g3, g4, g5, g6, g7, g8 ]))
      
      q = Fl::Framework::Asset::AccessGrant.build_query(only_data: d21, order: 'id',
                                                        except_permissions: Fl::Framework::Asset::Permission::Owner)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ g6, g7 ]))
      
      q = Fl::Framework::Asset::AccessGrant.build_query(order: 'id', offset: 2, limit: 2,
                                                        except_permissions: Fl::Framework::Asset::Permission::Owner)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints([ g3, g4 ]))
    end      
  end
  
  context '.accessible_query' do
    it 'should return grants correctly' do
      # trigger the data and grant creation
      ogl = owner_grants([ d10, d11, d20, d21, d12 ])
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]

      xl = [ g3, g8 ] | owner_grants([ d10, d20 ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a1, :any)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ g3, g8 ] | owner_grants([ d10, d20 ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a1, Fl::Framework::Access::Permission::Read)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ g5, g7 ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a4, Fl::Framework::Access::Permission::Read)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ g5 ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a4, Fl::Framework::Access::Permission::Write)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ g5 ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a4, Fl::Framework::Access::Permission::Edit)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ g1, g4 ] | owner_grants([ d11, d12, d21 ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a2, :any)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ g1, g4 ] | owner_grants([ d11, d12, d21 ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a2, [
                                                               Fl::Framework::Access::Permission::Read,
                                                               Fl::Framework::Access::Permission::Write
                                                             ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ ] | owner_grants([ d11, d12, d21 ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a2, [
                                                               Fl::Framework::Access::Permission::Edit
                                                             ])
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))
    end

    it 'should support filtering by type' do
      # trigger the data and grant creation
      ogl = owner_grants([ d10, d11, d20, d21, d12 ])
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]

      xl = ([ g3, g8 ] | owner_grants([ d10 ])).sort
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a1, :any,
                                                             only_types: TestDatumOne, order: 'id')
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints(xl))

      xl = ([ g3, g8 ] | owner_grants([ d10 ])).sort
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a1, Fl::Framework::Access::Permission::Read,
                                                             only_types: TestDatumOne, order: 'id')
      ll = q.to_a
      expect(obj_fingerprints(ll)).to match_array(obj_fingerprints(xl))

      xl = [ g5, g7 ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a4, Fl::Framework::Access::Permission::Read,
                                                             only_types: [ TestDatumTwo ], order: 'id')
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints(xl))

      xl = [ ] | owner_grants([ ])
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a4, Fl::Framework::Access::Permission::Read,
                                                             except_types: [ TestDatumTwo ], order: 'id')
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints(xl))

      xl = ([ g4 ] | owner_grants([ d21 ])).sort
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a2, [
                                                               Fl::Framework::Access::Permission::Read,
                                                               Fl::Framework::Access::Permission::Write
                                                             ],
                                                             only_types: TestDatumTwo, order: 'id')
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints(xl))
    end
    
    it 'should support order and pagination options' do
      # trigger the data and grant creation
      ogl = owner_grants([ d10, d11, d20, d21, d12 ])
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8 ]

      xl = ([ g1, g4 ] | owner_grants([ d11, d12, d21 ])).sort
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a2, [
                                                               Fl::Framework::Access::Permission::Read,
                                                               Fl::Framework::Access::Permission::Write
                                                             ],
                                                             order: 'id')
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints(xl))

      xl = ([ g1, g4 ] | owner_grants([ d11, d12, d21 ])).sort.slice(1..2)
      q = Fl::Framework::Asset::AccessGrant.accessible_query(a2, [
                                                               Fl::Framework::Access::Permission::Read,
                                                               Fl::Framework::Access::Permission::Write
                                                             ],
                                                             order: 'id',
                                                             offset: 1, limit: 2)
      ll = q.to_a
      expect(obj_fingerprints(ll)).to eql(obj_fingerprints(xl))
    end
  end
end
