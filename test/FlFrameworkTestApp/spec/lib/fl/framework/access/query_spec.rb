require 'rails_helper'
require 'test_object_helpers'
require 'test_access_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
  c.include Fl::Framework::Test::AccessHelpers
end

def target_owner_grants(target)
  _ag.build_query(only_targets: target, permissions: { all: _ap::Owner::BIT })
end

def x_targets(gl)
  gl.map do |g|
    t = g.target
    "#{t.value}"
  end
end

def x_docs(dl)
  dl.map do |d|
    "#{d.value}"
  end
end

RSpec.describe Fl::Framework::Access::Query do
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

  describe '.join_grants_table' do
    it 'should create the join' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a1 owns d10
        "#{a1.name} - #{d10.value}", 		# a2 write on d10 (g1)
        "#{a1.name} - #{d10.value}", 		# a3 read on d10 (g2)

        "#{a2.name} - #{d11.value}", 		# a2 owns d11
        "#{a2.name} - #{d11.value}", 		# a1 edit on d11 (g3)

        "#{a2.name} - #{d110.value}", 		# a2 owns d110
        
        "#{a2.name} - #{d12.value}", 		# a2 owns d12
        "#{a2.name} - #{d12.value}" 		# a1 write on d12 (g8)
      ]
      q = TestDatumOne.join_grants_table()
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}", 		# a1 owns d20
        "#{a1.name} - #{d20.value}", 		# a2 read on d20 (g4)
        "#{a1.name} - #{d20.value}", 		# a4 edit on d20 (g5)

        "#{a2.name} - #{d21.value}", 		# a2 owns d21
        "#{a2.name} - #{d21.value}", 		# a3 read on d21 (g6)
        "#{a2.name} - #{d21.value}", 		# a4 read on d21 (g7)

        "#{a1.name} - #{d22.value}" 		# a1 owns d22
      ]
      q = TestDatumTwo.join_grants_table()
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end

    it 'should customize the grants table alias' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a1 owns d10
        "#{a1.name} - #{d10.value}", 		# a2 write on d10 (g1)
        "#{a1.name} - #{d10.value}", 		# a3 read on d10 (g2)

        "#{a2.name} - #{d11.value}", 		# a2 owns d11
        "#{a2.name} - #{d11.value}", 		# a1 edit on d11 (g3)

        "#{a2.name} - #{d110.value}", 		# a2 owns d110
        
        "#{a2.name} - #{d12.value}", 		# a2 owns d12
        "#{a2.name} - #{d12.value}" 		# a1 write on d12 (g8)
      ]
      q = TestDatumOne.join_grants_table(table_alias: 'gt')
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end
  end

  describe '.add_granted_to_clause' do
    it 'should filter correctly' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a1 owns d10
        "#{a2.name} - #{d11.value}", 		# a1 edit on d11 (g3)
        "#{a2.name} - #{d12.value}" 		# a1 write on d12 (g8)
      ]
      q = TestDatumOne.join_grants_table().add_granted_to_clause(a1)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}", 		# a2 read on d20 (g4)
        "#{a2.name} - #{d21.value}" 		# a2 owns d21
      ]
      q = TestDatumTwo.join_grants_table().add_granted_to_clause(a2.fingerprint)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
      ]
      q = TestDatumOne.join_grants_table().add_granted_to_clause(a4)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end

    it 'should customize the grants table alias' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a1 owns d10
        "#{a2.name} - #{d11.value}", 		# a1 edit on d11 (g3)
        "#{a2.name} - #{d12.value}" 		# a1 write on d12 (g8)
      ]
      q = TestDatumOne.join_grants_table(table_alias: 'gt').add_granted_to_clause(a1, table_alias: 'gt')
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end
  end

  describe '.get_permission_mask' do
    it 'should accept integer values' do
      expect(TestDatumOne.get_permissions_mask({ all: 0x00001000 }, :all)).to eql(0x00001000)
      expect(TestDatumOne.get_permissions_mask({ any: 0x00001000 }, :any)).to eql(0x00001000)
    end

    it 'should accept integer values as strings' do
      expect(TestDatumOne.get_permissions_mask({ all: '12' }, :all)).to eql(12)
      expect(TestDatumOne.get_permissions_mask({ any: '12' }, :any)).to eql(12)

      expect(TestDatumOne.get_permissions_mask({ all: '0x00001c00' }, :all)).to eql(0x00001c00)
      expect(TestDatumOne.get_permissions_mask({ any: '0x00001c00' }, :any)).to eql(0x00001c00)
    end

    it 'should accept permission names as strings' do
      expect(TestDatumOne.get_permissions_mask({ all: _ap::Read::NAME.to_s }, :all)).to eql(_ap::Read::BIT)
      expect(TestDatumOne.get_permissions_mask({ any: _ap::Read::NAME.to_s }, :any)).to eql(_ap::Read::BIT)

      expect(TestDatumOne.get_permissions_mask({ all: _ap::Edit::NAME.to_s }, :all)).to eql(_ap::Read::BIT | _ap::Write::BIT)
      expect(TestDatumOne.get_permissions_mask({ any: _ap::Edit::NAME.to_s }, :any)).to eql(_ap::Read::BIT | _ap::Write::BIT)
    end

    it 'should accept permission names' do
      expect(TestDatumOne.get_permissions_mask({ all: _ap::Read::NAME }, :all)).to eql(_ap::Read::BIT)
      expect(TestDatumOne.get_permissions_mask({ any: _ap::Read::NAME }, :any)).to eql(_ap::Read::BIT)

      expect(TestDatumOne.get_permissions_mask({ all: _ap::Edit::NAME }, :all)).to eql(_ap::Read::BIT | _ap::Write::BIT)
      expect(TestDatumOne.get_permissions_mask({ any: _ap::Edit::NAME }, :any)).to eql(_ap::Read::BIT | _ap::Write::BIT)
    end

    it 'should accept permission objects' do
      expect(TestDatumOne.get_permissions_mask({ all: _ap::Read }, :all)).to eql(_ap::Read::BIT)
      expect(TestDatumOne.get_permissions_mask({ any: _ap::Read }, :any)).to eql(_ap::Read::BIT)

      expect(TestDatumOne.get_permissions_mask({ all: _ap::Edit }, :all)).to eql(_ap::Read::BIT | _ap::Write::BIT)
      expect(TestDatumOne.get_permissions_mask({ any: _ap::Edit }, :any)).to eql(_ap::Read::BIT | _ap::Write::BIT)
    end
  end

  describe '.add_permission_clauses' do
    it 'should support :all' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a3 read on d10 (g2)
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses({ all: _ap::Read })
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}" 		# a4 edit on d20 (g5)
      ]
      q = TestDatumTwo.join_grants_table().add_permission_clauses({ all: _ap::Write })
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses({ all: _ap::Edit })
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}" 		# a4 edit on d20 (g5)
      ]
      q = TestDatumTwo.join_grants_table().add_permission_clauses({ all: _ap::Edit })
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end

    it 'should support :any' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a2 write on d10 (g1)
        "#{a1.name} - #{d10.value}", 		# a3 read on d10 (g2)
        "#{a2.name} - #{d11.value}", 		# a1 edit on d11 (g3)
        "#{a2.name} - #{d12.value}" 		# a1 write on d12 (g8)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses({ any: _ap::Read::BIT | _ap::Write::BIT })
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}", 		# a2 read on d20 (g4)
        "#{a1.name} - #{d20.value}", 		# a4 edit on d20 (g5)
        "#{a2.name} - #{d21.value}", 		# a3 read on d21 (g6)
        "#{a2.name} - #{d21.value}" 		# a4 read on d21 (g7)
      ]
      q = TestDatumTwo.join_grants_table().add_permission_clauses({ any: _ap::Read::BIT | _ap::Write::BIT })
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end

    it 'should accept an integer' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a3 read on d10 (g2)
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses(_ap::Read::BIT)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}" 		# a4 edit on d20 (g5)
      ]
      q = TestDatumTwo.join_grants_table().add_permission_clauses(_ap::Write::BIT)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end

    it 'should accept permission names' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a3 read on d10 (g2)
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses(_ap::Read::NAME)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}" 		# a4 edit on d20 (g5)
      ]
      q = TestDatumTwo.join_grants_table().add_permission_clauses(_ap::Write::NAME)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses(_ap::Edit::NAME)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}" 		# a4 edit on d20 (g5)
      ]
      q = TestDatumTwo.join_grants_table().add_permission_clauses(_ap::Edit::NAME)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end

    it 'should accept permission objects' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a3 read on d10 (g2)
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses(_ap::Read)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}" 		# a4 edit on d20 (g5)
      ]
      q = TestDatumTwo.join_grants_table().add_permission_clauses(_ap::Write)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses(_ap::Edit)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}" 		# a4 edit on d20 (g5)
      ]
      q = TestDatumTwo.join_grants_table().add_permission_clauses(_ap::Edit)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end

    it 'should accept composite descriptors' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a1.name} - #{d10.value}", 		# a1 owns d10
        "#{a1.name} - #{d10.value}", 		# a3 read on d10 (g2)
        "#{a2.name} - #{d11.value}", 		# a2 owns d11
        "#{a2.name} - #{d11.value}", 		# a1 edit on d11 (g3)
        "#{a2.name} - #{d110.value}", 		# a2 owns d110
        "#{a2.name} - #{d12.value}" 		# a2 owns d12
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses([ _ap::Read, :or, _ap::Owner ])
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a1.name} - #{d20.value}", 		# a1 owns d20
        "#{a1.name} - #{d20.value}", 		# a4 edit on d20 (g5)
        "#{a2.name} - #{d21.value}", 		# a2 owns d21
        "#{a1.name} - #{d22.value}" 		# a1 owns d22
      ]
      q = TestDatumTwo.join_grants_table().add_permission_clauses([ _ap::Edit, :or, _ap::Owner ])
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end

    it 'should process equivalent descriptors equally' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = [
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses(_ap::Edit::NAME)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses(_ap::Read::BIT | _ap::Write::BIT)
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses({ all: _ap::Read::BIT | _ap::Write::BIT })
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)

      xl = [
        "#{a2.name} - #{d11.value}" 		# a1 edit on d11 (g3)
      ]
      q = TestDatumOne.join_grants_table().add_permission_clauses([ _ap::Read, :and, _ap::Write::NAME ])
      ql = q.map { |d| "#{d.owner.name} - #{d.value}" }
      expect(ql.sort).to eql(xl.sort)
    end
  end
  
  describe 'combining clauses' do
    it 'should behave like Grant.accessible_query' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = x_targets([ g3 ]) | x_targets(target_owner_grants([ d10 ]))
      q = _ag.accessible_query(a1, _ap::Read, only_types: TestDatumOne)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumOne.join_grants_table().add_granted_to_clause(a1).add_permission_clauses([ _ap::Read, :or, _ap::Owner ])
      expect(x_docs(q)).to match_array(xl)

      xl = x_targets([ g5, g7 ]) | x_targets(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Read::BIT, only_types: TestDatumTwo)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumTwo.join_grants_table().add_granted_to_clause(a4).add_permission_clauses([ _ap::Read, :or, _ap::Owner ])
      expect(x_docs(q)).to match_array(xl)

      xl = x_targets([ g5 ]) | x_targets(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Write, only_types: TestDatumTwo)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumTwo.join_grants_table().add_granted_to_clause(a4).add_permission_clauses([ _ap::Write, :or, _ap::Owner ])
      expect(x_docs(q)).to match_array(xl)

      xl = x_targets([ g5 ]) | x_targets(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Edit, only_types: TestDatumTwo)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumTwo.join_grants_table().add_granted_to_clause(a4).add_permission_clauses([ _ap::Edit, :or, _ap::Owner ])
      expect(x_docs(q)).to match_array(xl)

      xl = x_targets([ g1 ]) | x_targets(target_owner_grants([ d11, d110, d12 ]))
      q = _ag.accessible_query(a2, nil, only_types: TestDatumOne)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumOne.join_grants_table().add_granted_to_clause(a2)
      expect(x_docs(q)).to match_array(xl)
    end
  end
  
  describe '.add_access_clauses' do
    it 'should behave like Grant.accessible_query' do
      # trigger the data and grant creation
      dl = [ d10, d11, d110, d12, d20, d21, d22, d30, d40 ]
      gl = [ g1, g2, g3, g4, g5, g6, g7, g8, g9, g10 ]

      xl = x_targets([ g3 ]) | x_targets(target_owner_grants([ d10 ]))
      q = _ag.accessible_query(a1, _ap::Read, only_types: TestDatumOne)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumOne.add_access_clauses(a1, [ _ap::Read, :or, _ap::Owner ])
      expect(x_docs(q)).to match_array(xl)

      xl = x_targets([ g5, g7 ]) | x_targets(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Read::BIT, only_types: TestDatumTwo)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumTwo.add_access_clauses(a4, [ _ap::Read, :or, _ap::Owner ])
      expect(x_docs(q)).to match_array(xl)

      xl = x_targets([ g5 ]) | x_targets(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Write, only_types: TestDatumTwo)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumTwo.add_access_clauses(a4, [ _ap::Write, :or, _ap::Owner ])
      expect(x_docs(q)).to match_array(xl)

      xl = x_targets([ g5 ]) | x_targets(target_owner_grants([ ]))
      q = _ag.accessible_query(a4, _ap::Edit, only_types: TestDatumTwo)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumTwo.add_access_clauses(a4, [ _ap::Edit, :or, _ap::Owner ])
      expect(x_docs(q)).to match_array(xl)

      xl = x_targets([ g1 ]) | x_targets(target_owner_grants([ d11, d110, d12 ]))
      q = _ag.accessible_query(a2, nil, only_types: TestDatumOne)
      expect(x_targets(q)).to match_array(xl)
      q = TestDatumOne.add_access_clauses(a2, nil)
      expect(x_docs(q)).to match_array(xl)
    end
  end
end
