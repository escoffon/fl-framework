require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe Fl::Framework::List::ListItem, type: :model do
  let(:a1) { create(:test_actor) }
  let(:a2) { create(:test_actor) }
  let(:a3) { create(:test_actor) }
  let(:d10) { create(:test_datum_one, owner: a1, value: 10) }
  let(:d11) { create(:test_datum_one, owner: a2, value: 11) }
  let(:d12) { create(:test_datum_one, owner: a2, value: 12) }
  let(:d20) { create(:test_datum_two, owner: a1, value: 'v20') }
  let(:d21) { create(:test_datum_two, owner: a2, value: 'v21') }
  let(:d22) { create(:test_datum_two, owner: a1, value: 'v22') }
  let(:d30) { create(:test_datum_three, owner: a1, value: 30) }
  let(:l1) { create(:list, owner: a1) }
  let(:l2) { create(:list, owner: a1) }

  describe '#initialize' do
    it 'should fail with empty attributes' do
      li1 = Fl::Framework::List::ListItem.new
      expect(li1.valid?).to eq(false)
      expect(li1.errors.messages.keys).to contain_exactly(:list, :listed_object)
    end

    it 'should succeed with list and listable' do
      l = create(:list)
      li1 = Fl::Framework::List::ListItem.new(list: l, listed_object: d11)
      expect(li1.valid?).to eq(true)
      expect(li1.owner).to be_nil
      expect(li1.list.fingerprint).to eql(l.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d11.fingerprint)
    end

    it 'should accept an owner attribute' do
      li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a2)
      expect(li1.valid?).to eq(true)
      expect(li1.owner.id).to eql(a2.id)
    end

    it 'should accept a name attribute' do
      li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, name: 'item1')
      expect(li1.valid?).to eq(true)
      expect(li1.name).to eql('item1')
    end

    it 'should use the list owner if necessary' do
      l = create(:list)
      li1 = Fl::Framework::List::ListItem.new(list: l, listed_object: d11)
      expect(li1.valid?).to eq(true)
      expect(li1.owner).to be_nil

      l2 = create(:list, owner: a1)
      li2 = Fl::Framework::List::ListItem.new(list: l2, listed_object: d11)
      expect(li2.valid?).to eq(true)
      expect(li2.owner.id).to eql(a1.id)
    end

    it 'should accept fingerprint arguments' do
      l = create(:list)
      li1 = Fl::Framework::List::ListItem.new(list: l.fingerprint, listed_object: d11.fingerprint,
                                              owner: a2.fingerprint, state_updated_by: a1.fingerprint)
      expect(li1.valid?).to eq(true)
      expect(li1.owner.fingerprint).to eql(a2.fingerprint)
      expect(li1.list.fingerprint).to eql(l.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d11.fingerprint)
    end
  end

  describe 'creation' do
    it 'should set the fingerprint attributes' do
      li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a2, name: 'item1')
      expect(li1.valid?).to eq(true)
      expect(li1.owner_fingerprint).to be_nil
      expect(li1.listed_object_fingerprint).to be_nil
      
      expect(li1.save).to eq(true)
      expect(li1.owner.id).to eql(a2.id)
      expect(li1.valid?).to eq(true)
      expect(li1.name).to eql('item1')
      expect(li1.owner_fingerprint).to eql(li1.owner.fingerprint)
      expect(li1.listed_object_fingerprint).to eql(li1.listed_object.fingerprint)
    end
  end
  
  describe 'validation' do
    it 'should fail if :listed_object is not a listable' do
      d3 = create(:test_datum_three, owner: a1)
      li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d3)
      expect(li1.valid?).to eq(false)
      expect(li1.errors.messages.keys).to contain_exactly(:listed_object)
    end

    context '#name' do
      it 'should accept punctuation in name' do
        d21 = create(:test_datum_two, owner: a1, value: 'v21')
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d21, name: 'l1 - d21')
        expect(li1.valid?).to eq(true)

        d22 = create(:test_datum_two, owner: a1, value: 'v22')
        li2 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d22, name: 'l1 - d22 .+;:')
        expect(li2.valid?).to eq(true)
      end
      
      it 'should fail if name contains / or \\' do
        d21 = create(:test_datum_two, owner: a1, value: 'v21')
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d21, name: 'l1/d21')
        expect(li1.valid?).to eq(false)
        expect(li1.errors.messages.keys).to contain_exactly(:name)

        d22 = create(:test_datum_two, owner: a1, value: 'v22')
        li2 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d22, name: 'l1\\d22')
        expect(li2.valid?).to eq(false)
        expect(li2.errors.messages.keys).to contain_exactly(:name)
      end
      
      it 'should fail if name is longer than 200 characters' do
        d21 = create(:test_datum_two, owner: a1, value: 'v21')
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d21,
                                                name: '0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 0123456789 ')
        expect(li1.valid?).to eq(false)
        expect(li1.errors.messages.keys).to contain_exactly(:name)
      end
      
      it 'should fail on duplicate names on the same list' do
        d21 = create(:test_datum_two, owner: a1, value: 'v21')
        li1 = Fl::Framework::List::ListItem.create(list: l1, listed_object: d21, name: 'item1')
        expect(li1.valid?).to eq(true)

        d22 = create(:test_datum_two, owner: a1, value: 'v22')
        li2 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d22, name: 'item1')
        expect(li2.valid?).to eq(false)
        expect(li2.errors.messages.keys).to contain_exactly(:name)

        li2.name = 'item2'
        expect(li2.save).to eq(true)
        li2.name = 'item1'
        expect(li2.valid?).to eq(false)
      end
      
      it 'should accept duplicate names on different lists' do
        d21 = create(:test_datum_two, owner: a1, value: 'v21')
        li1 = Fl::Framework::List::ListItem.create(list: l1, listed_object: d21, name: 'item1')
        expect(li1.valid?).to eq(true)

        d22 = create(:test_datum_two, owner: a1, value: 'v22')
        li2 = Fl::Framework::List::ListItem.new(list: l2, listed_object: d22, name: 'item1')
        expect(li2.valid?).to eq(true)
      end
    end
  end
  
  describe '#update_attributes' do
    it 'should ignore :list, :listed_object, and :owner attributes' do
      li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                              state: Fl::Framework::List::ListItem::STATE_SELECTED)
      expect(li1.valid?).to eq(true)
      expect(li1.list.fingerprint).to eql(l1.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d11.fingerprint)
      expect(li1.owner.fingerprint).to eql(a1.fingerprint)
      expect(li1.state).to eql(Fl::Framework::List::ListItem::STATE_SELECTED)

      l2 = create(:list)
      li1.update_attributes(list: l2, listed_object: d12, owner: a2,
                            state: Fl::Framework::List::ListItem::STATE_DESELECTED)
      expect(li1.valid?).to eq(true)
      expect(li1.list.fingerprint).to eql(l1.fingerprint)
      expect(li1.listed_object.fingerprint).to eql(d11.fingerprint)
      expect(li1.owner.fingerprint).to eql(a1.fingerprint)
      expect(li1.state).to eql(Fl::Framework::List::ListItem::STATE_DESELECTED)
    end
  end

  describe "#list=" do
    it 'should not overwrite :list for a persisted object' do
      li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                              state: Fl::Framework::List::ListItem::STATE_SELECTED)

      l2 = create(:list)
      li1.list = l2
      expect(li1.list.fingerprint).to eql(l2.fingerprint)
      expect(li1.save).to eql(true)
      li1.list = l1
      expect(li1.list.fingerprint).to eql(l2.fingerprint)
    end
  end

  describe "#listed_object=" do
    it 'should not overwrite :listed_object for a persisted object' do
      li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                              state: Fl::Framework::List::ListItem::STATE_SELECTED)

      li1.listed_object = d12
      expect(li1.listed_object.fingerprint).to eql(d12.fingerprint)
      expect(li1.save).to eql(true)
      li1.listed_object = d11
      expect(li1.listed_object.fingerprint).to eql(d12.fingerprint)
    end
  end
  
  describe 'state management' do
    context '#set_state' do
      it 'should store the actor' do
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                                state: Fl::Framework::List::ListItem::STATE_SELECTED)
        expect(li1.state).to eql(Fl::Framework::List::ListItem::STATE_SELECTED)
        expect(li1.state_updated_by).to be_an_instance_of(TestActor)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)

        li1.set_state(Fl::Framework::List::ListItem::STATE_DESELECTED, a2)
        expect(li1.state).to eql(Fl::Framework::List::ListItem::STATE_DESELECTED)
        expect(li1.state_updated_by).to be_an_instance_of(TestActor)
        expect(li1.state_updated_by.fingerprint).to eql(a2.fingerprint)
      end

      it "should use the item's owner if necessary" do
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                                state: Fl::Framework::List::ListItem::STATE_SELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)

        li1.set_state(Fl::Framework::List::ListItem::STATE_DESELECTED, a2)
        expect(li1.state).to eql(Fl::Framework::List::ListItem::STATE_DESELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a2.fingerprint)

        li1.set_state(Fl::Framework::List::ListItem::STATE_SELECTED)
        expect(li1.state).to eql(Fl::Framework::List::ListItem::STATE_SELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)
      end
    end

    context '#state=' do
      it "should use the item's owner" do
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                                state: Fl::Framework::List::ListItem::STATE_SELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)

        li1.set_state(Fl::Framework::List::ListItem::STATE_DESELECTED, a2)
        expect(li1.state).to eql(Fl::Framework::List::ListItem::STATE_DESELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a2.fingerprint)

        li1.state = Fl::Framework::List::ListItem::STATE_SELECTED
        expect(li1.state).to eql(Fl::Framework::List::ListItem::STATE_SELECTED)
        expect(li1.state_updated_by.fingerprint).to eql(a1.fingerprint)
      end
    end

    context '#state_note=' do
      it "should update the note" do
        n1 = 'state note 1'
        n2 = 'state note 2'
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                                state: Fl::Framework::List::ListItem::STATE_SELECTED,
                                                state_note: n1)
        expect(li1.state_note).to eql(n1)
        li1.state_note = n2
        expect(li1.state_note).to eql(n2)
      end

      it "should sanitize the note" do
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                                state: Fl::Framework::List::ListItem::STATE_SELECTED)

        # we only check for simple sanitizing, under the assumption that if it works for this it also
        # works for all others (the attribute filters are tested separately)
        
        html = '<p>Script: <script type="text/javascript">script contents</script> here</p>'
        nhtm = '<p>Script:  here</p>'
        li1.state_note = html
        expect(li1.state_note).to eql(nhtm)
      end
    end
  end

  describe "model hash support" do
    context "#to_hash" do
      it "should track :verbosity" do
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                                state: Fl::Framework::List::ListItem::STATE_SELECTED)

        id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
        h = li1.to_hash(a1, { verbosity: :id })
        expect(h.keys).to match_array(id_keys)

        ignore_keys = id_keys | [ ]
        h = li1.to_hash(a1, { verbosity: :ignore })
        expect(h.keys).to match_array(ignore_keys)

        minimal_keys = id_keys | [ :owner, :list, :listed_object, :readonly_state, :name,
                                   :state, :sort_order, :item_summary, :created_at, :updated_at ]
        h = li1.to_hash(a1, { verbosity: :minimal })
        expect(h.keys).to match_array(minimal_keys)

        standard_keys = minimal_keys | [ :state_updated_at, :state_updated_by, :state_note ]
        h = li1.to_hash(a1, { verbosity: :standard })
        expect(h.keys).to match_array(standard_keys)

        verbose_keys = standard_keys | [ ]
        h = li1.to_hash(a1, { verbosity: :verbose })
        expect(h.keys).to match_array(verbose_keys)

        complete_keys = verbose_keys | [ ]
        h = li1.to_hash(a1, { verbosity: :complete })
        expect(h.keys).to match_array(complete_keys)
      end

      it "should customize key lists" do
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                                state: Fl::Framework::List::ListItem::STATE_SELECTED)

        id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
        h_keys = id_keys | [ :list ]
        h = li1.to_hash(a1, { verbosity: :id, include: [ :list ] })
        expect(h.keys).to match_array(h_keys)

        minimal_keys = id_keys | [ :owner, :list, :listed_object, :readonly_state, :name,
                                   :state, :sort_order, :item_summary, :created_at, :updated_at ]
        h_keys = minimal_keys - [ :list, :sort_order ]
        h = li1.to_hash(a1, { verbosity: :minimal, except: [ :list, :sort_order ] })
        expect(h.keys).to match_array(h_keys)
      end

      it "should customize key lists for subobjects" do
        li1 = Fl::Framework::List::ListItem.new(list: l1, listed_object: d11, owner: a1,
                                                state: Fl::Framework::List::ListItem::STATE_SELECTED)

        id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
        h = li1.to_hash(a1, { verbosity: :minimal })
        lo_keys = id_keys + [ :owner, :title, :value, :created_at, :updated_at, :permissions ]
        expect(h[:listed_object].keys).to match_array(lo_keys)

        h = li1.to_hash(a1, {
                          verbosity: :minimal,
                          to_hash: {
                            listed_object: { verbosity: :minimal },
                            owner: { verbosity: :id },
                            list: { verbosity: :id, include: :title }
                          }
                        })
        lo_keys = id_keys + [ :title, :value, :created_at, :updated_at, :permissions ]
        expect(h[:listed_object].keys).to match_array(lo_keys)
        l_keys = id_keys + [ :title ]
        expect(h[:list].keys).to match_array(l_keys)
        o_keys = id_keys + [ ]
        expect(h[:owner].keys).to match_array(o_keys)
      end
    end
  end

  describe ".build_query" do
    it 'should generate a simple query from default options' do
      l10 = create(:list, objects: [ d10, d20, d21, d11 ])
      l11 = create(:list, objects: [ d10, d22, d20, d12 ])
      
      q = Fl::Framework::List::ListItem.build_query()
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d21, d11, d10, d22, d20, d12 ]))
    end

    it 'should process :only_lists and :except_lists' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Framework::List::ListItem.build_query(only_lists: l10.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_lists: [ l10.fingerprint ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_lists: l10)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Framework::List::ListItem.build_query(except_lists: l11.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Framework::List::ListItem.build_query(except_lists: [ l11.fingerprint ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d21, d11 ]))
      
      q = Fl::Framework::List::ListItem.build_query(except_lists: [ l10, l11.fingerprint ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))
    end

    it 'should process :only_owners and :except_owners' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Framework::List::ListItem.build_query(only_owners: a1.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_owners: [ a1.fingerprint ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_owners: a1)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Framework::List::ListItem.build_query(except_owners: a2.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Framework::List::ListItem.build_query(except_owners: [ a2.fingerprint ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d11, d22, d20, d12 ]))
      
      q = Fl::Framework::List::ListItem.build_query(except_owners: [ a1, a2.fingerprint ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))
    end

    it 'should process :only_listables and :except_listables' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Framework::List::ListItem.build_query(only_listables: d10.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d10 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_listables: [ d10.fingerprint, d12 ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d10, d12 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_listables: d10)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d10 ]))
      
      q = Fl::Framework::List::ListItem.build_query(except_listables: d22.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d21, d11, d10, d20, d12 ]))
      
      q = Fl::Framework::List::ListItem.build_query(except_listables: [ d22.fingerprint, d10, d11 ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20, d21, d20, d12 ]))
      
      q = Fl::Framework::List::ListItem.build_query(except_listables: [ d10, d11, d12, d20, d21, d22 ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))
    end

    it 'should filter by combination of list, owner, and listable' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Framework::List::ListItem.build_query(only_lists: l10.fingerprint, only_owners: a1)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d11 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_lists: [ l11 ], except_owners: [ a1 ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_owners: a1, only_listables: [ d10, d11, d21 ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d11 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_owners: a1, except_listables: [ d10 ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20, d11, d22, d20, d12 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_lists: l10, only_owners: a1, only_listables: d20)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_lists: l10, only_owners: a1, only_listables: d21)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))

      q = Fl::Framework::List::ListItem.build_query(only_lists: l10, except_owners: a1, except_listables: d21)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))

      q = Fl::Framework::List::ListItem.build_query(only_lists: l10, only_owners: a1,
                                                    except_listables: [ d10, d21 ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20, d11 ]))
    end

    it 'should process :order, :offset, :limit' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Framework::List::ListItem.build_query(only_lists: l10.fingerprint, only_owners: a1,
                                                    offset: 1, limit: 1)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_owners: a1, except_listables: [ d10 ],
                                                    order: 'list_id ASC, sort_order DESC')
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d11, d20, d12, d20, d22 ]))
      
      q = Fl::Framework::List::ListItem.build_query(only_owners: a1, except_listables: [ d10 ],
                                                    offset: 1, limit: 3,
                                                    order: 'list_id ASC, sort_order DESC')
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20, d12, d20 ]))
    end
  end

  describe ".query_for_list" do
    it 'should restrict to the given list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      
      q = Fl::Framework::List::ListItem.query_for_list(l10)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10, d20, d21, d11 ]))

      q = Fl::Framework::List::ListItem.query_for_list(l11, only_owners: a1)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22, d20, d12 ]))
      
      q = Fl::Framework::List::ListItem.query_for_list(l11, except_owners: [ a1 ])
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10 ]))

      q = Fl::Framework::List::ListItem.query_for_list(l10, only_owners: a1, order: 'sort_order DESC')
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d11, d20, d10 ]))

      q = Fl::Framework::List::ListItem.query_for_list(l10, only_owners: a1, limit: 1, offset: 1,
                                                       order: 'sort_order DESC')
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20 ]))
    end
  end

  describe ".query_for_listable" do
    it 'should restrict to the given listable' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])
      l12 = create(:list, objects: [ [ d21, a2 ], [ d22, a1 ] ])
      l13 = create(:list, objects: [ [ d22, a2 ], [ d12, a2 ] ])

      # The default sort order is 'updated_at DESC'
      
      q = Fl::Framework::List::ListItem.query_for_listable(d20)
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l11, l10 ]))
      
      q = Fl::Framework::List::ListItem.query_for_listable(d12)
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l13, l11 ]))
      
      q = Fl::Framework::List::ListItem.query_for_listable(d12, order: 'list_id ASC')
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l11, l13 ]))
    end
  end

  describe ".query_for_listable_in_list" do
    it 'should find a listable in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      q = Fl::Framework::List::ListItem.query_for_listable_in_list(d20, l10)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20 ]))
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l10 ]))

      q = Fl::Framework::List::ListItem.query_for_listable_in_list(d22.fingerprint, l11)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22 ]))
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l11 ]))

      q = Fl::Framework::List::ListItem.query_for_listable_in_list(d20, l10.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d20 ]))
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l10 ]))

      q = Fl::Framework::List::ListItem.query_for_listable_in_list(d22.fingerprint, l11.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22 ]))
      ql = q.map { |li| li.list }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ l11 ]))
    end

    it 'should not find a listable not in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      q = Fl::Framework::List::ListItem.query_for_listable_in_list(d11, l11)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))

      q = Fl::Framework::List::ListItem.query_for_listable_in_list(d11.fingerprint, l11)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))

      q = Fl::Framework::List::ListItem.query_for_listable_in_list(d11, l11.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))

      q = Fl::Framework::List::ListItem.query_for_listable_in_list(d11.fingerprint, l11.fingerprint)
      ql = q.map { |li| li.listed_object }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))
    end
  end

  describe ".find_listable_in_list" do
    it 'should find a listable in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      l = Fl::Framework::List::ListItem.find_listable_in_list(d20, l10)
      expect(l.fingerprint).to eql(d20.fingerprint)

      l = Fl::Framework::List::ListItem.find_listable_in_list(d22.fingerprint, l11)
      expect(l.fingerprint).to eql(d22.fingerprint)

      l = Fl::Framework::List::ListItem.find_listable_in_list(d20, l10.fingerprint)
      expect(l.fingerprint).to eql(d20.fingerprint)

      l = Fl::Framework::List::ListItem.find_listable_in_list(d22.fingerprint, l11.fingerprint)
      expect(l.fingerprint).to eql(d22.fingerprint)
    end

    it 'should not find a listable not in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      l = Fl::Framework::List::ListItem.find_listable_in_list(d11, l11)
      expect(l).to be_nil

      l = Fl::Framework::List::ListItem.find_listable_in_list(d11.fingerprint, l11)
      expect(l).to be_nil

      l = Fl::Framework::List::ListItem.find_listable_in_list(d11, l11.fingerprint)
      expect(l).to be_nil

      l = Fl::Framework::List::ListItem.find_listable_in_list(d11.fingerprint, l11.fingerprint)
      expect(l).to be_nil
    end
  end

  describe ".refresh_item_summaries" do
    it 'should update all summaries' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      nt = 'new title for summary'
      d20.title = nt
      expect(d20.save).to eql(true)
      d20.reload
      expect(d20.title).to eql(nt)
      q = Fl::Framework::List::ListItem.query_for_listable(d20)
      ql = q.map { |li| li.item_summary }
      expect(ql).to eql([ "my title: #{d20.title}", "my title: #{nt}" ])
    end
  end

  describe ".resolve_object" do
    it 'should return a list item as is' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      li = l10.list_items.first
      o = Fl::Framework::List::ListItem.resolve_object(li, l10, a2)
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(o.owner.fingerprint).to eql(a1.fingerprint)
    end

    it 'should process a fingerprint' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      o = Fl::Framework::List::ListItem.resolve_object(d22.fingerprint, l10, a2)
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
    end

    it 'should process a model instance' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      o = Fl::Framework::List::ListItem.resolve_object(d22, l10, a2)
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
    end

    it 'should process a hash' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      o = Fl::Framework::List::ListItem.resolve_object({ listed_object: d22 }, l10, a2)
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = Fl::Framework::List::ListItem.resolve_object({ listed_object: d22.fingerprint }, l10, a2)
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
    end

    it 'should fail if a list item is not in list' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      li = l10.list_items.first
      o = Fl::Framework::List::ListItem.resolve_object(li, l11, a2)
      expect(o).to be_an_instance_of(String)
    end

    it 'should fail if the resolved object is not listable' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])

      o = Fl::Framework::List::ListItem.resolve_object(d30, l10, a2)
      expect(o).to be_an_instance_of(String)

      o = Fl::Framework::List::ListItem.resolve_object(d30.fingerprint, l10, a2)
      expect(o).to be_an_instance_of(String)

      o = Fl::Framework::List::ListItem.resolve_object({ listed_object: d30.fingerprint }, l10, a2)
      expect(o).to be_an_instance_of(String)
    end
  end

  describe ".normalize_objects" do
    it 'should resolve correctly' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      objects = [ l10.list_items.first,
                  d22.fingerprint, d22,
                  { listed_object: d22 }, { listed_object: d22.fingerprint },
                  l11.list_items.first,
                  d30, d30.fingerprint, { listed_object: d30 },
                  { listed_object: d21, owner: a3, name: 'd21' },
                  { listed_object: d12, owner: a2, name: 'd12' }
                ]
      errcount, resolved = Fl::Framework::List::ListItem.normalize_objects(objects, l10, a2)
      expect(errcount).to eql(4)
      
      o = resolved[0]
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d10.fingerprint)
      expect(o.owner.fingerprint).to eql(a1.fingerprint)

      o = resolved[1]
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = resolved[2]
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = resolved[3]
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = resolved[4]
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d22.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)

      o = resolved[5]
      expect(o).to be_an_instance_of(String)

      o = resolved[6]
      expect(o).to be_an_instance_of(String)

      o = resolved[7]
      expect(o).to be_an_instance_of(String)

      o = resolved[8]
      expect(o).to be_an_instance_of(String)

      o = resolved[9]
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d21.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
      expect(o.name).to eql('d21')

      o = resolved[10]
      expect(o).to be_an_instance_of(Fl::Framework::List::ListItem)
      expect(o.list.fingerprint).to eql(l10.fingerprint)
      expect(o.listed_object.fingerprint).to eql(d12.fingerprint)
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
      expect(o.name).to eql('d12')
    end

    it 'should accept a nil owner argument' do
      l10 = create(:list, objects: [ [ d10, a1 ], [ d20, a1 ], [ d21, a2 ], [ d11, a1 ] ])
      l11 = create(:list, objects: [ [ d10, a2 ], [ d22, a1 ], [ d20, a1 ], [ d12, a1 ] ])

      objects = [ l10.list_items.first,
                  d22.fingerprint, d22,
                  { listed_object: d22 }, { listed_object: d22.fingerprint },
                  { listed_object: d21, owner: a3, name: 'd21' },
                  { listed_object: d12, owner: a2, name: 'd12' }
                ]
      errcount, resolved = Fl::Framework::List::ListItem.normalize_objects(objects, l10)
      expect(errcount).to eql(0)
      
      o = resolved[0]
      expect(o.owner.fingerprint).to eql(a1.fingerprint)

      o = resolved[1]
      expect(o.owner.fingerprint).to eql(a1.fingerprint)

      o = resolved[2]
      expect(o.owner.fingerprint).to eql(a1.fingerprint)

      o = resolved[3]
      expect(o.owner.fingerprint).to eql(d22.owner.fingerprint)

      o = resolved[4]
      expect(o.owner.fingerprint).to eql(d22.owner.fingerprint)

      o = resolved[5]
      expect(o.owner.fingerprint).to eql(a3.fingerprint)

      o = resolved[6]
      expect(o.owner.fingerprint).to eql(a2.fingerprint)
    end
  end
end
