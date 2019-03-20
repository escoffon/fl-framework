require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe Fl::Framework::List::Listable, type: :model do
  let(:a1) { create(:test_actor) }
  let(:a2) { create(:test_actor) }
  let(:d10_title) { 'd10 - title' }
  let(:d20_title) { 'd20 - title' }
  let(:d30_title) { 'd30 - title' }
  let(:d10) { create(:test_datum_one, owner: a1, title: d10_title, value: 101) }
  let(:d20) { create(:test_datum_two, owner: a2, title: d20_title, value: 'v201') }
  let(:d30) { create(:test_datum_three, owner: a2, title: d30_title, value: 301) }

  describe '#listable?' do
    it 'should be defined for all ActiveRecord classes' do
      expect(d10.methods).to include(:listable?)
      expect(d20.methods).to include(:listable?)
      expect(d30.methods).to include(:listable?)

      expect(TestActor.methods).to include(:listable?)
      expect(TestActorTwo.methods).to include(:listable?)
      expect(TestDatumOne.methods).to include(:listable?)
      expect(TestDatumTwo.methods).to include(:listable?)
    end

    it 'should return true for classes marked listable' do
      expect(d10.listable?).to eql(true)
      expect(d20.listable?).to eql(true)
      expect(d30.listable?).to eql(false)

      expect(TestActor.listable?).to eql(false)
      expect(TestActorTwo.listable?).to eql(false)
      expect(TestDatumOne.listable?).to eql(true)
      expect(TestDatumTwo.listable?).to eql(true)
      expect(TestDatumThree.listable?).to eql(false)
    end
  end
  
  describe '#list_item_summary' do
    it 'should be defined for all ActiveRecord classes' do
      expect(d10.methods).to include(:list_item_summary)
      expect(d20.methods).to include(:list_item_summary)
      expect(d30.methods).to include(:list_item_summary)
    end

    it 'should call the correct summary method' do
      expect(d10.list_item_summary).to eql(d10_title)
      expect(d20.list_item_summary).to eql("my title: #{d20_title}")
      expect(d30.list_item_summary).to eql('')
    end
  end
  
  describe '#listable_containers' do
    let(:d11) { create(:test_datum_one, owner: a2, value: 11) }
    let(:d21) { create(:test_datum_two, owner: a1, value: 'v21') }

    it 'should return the correct list' do
      l1 = create(:list, owner: a1, objects: [ [ d10, a1 ], [ d20, a2 ] ])
      l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

      d10_c = d10.listable_containers
      d10_l = d10_c.map { |li| li.list.fingerprint }
      expect(d10_l).to contain_exactly(l1.fingerprint)
      d10_d = d10_c.map { |li| li.listed_object.fingerprint }
      expect(d10_d).to contain_exactly(d10.fingerprint)

      d20_c = d20.listable_containers
      d20_l = d20_c.map { |li| li.list.fingerprint }
      expect(d20_l).to contain_exactly(l1.fingerprint, l2.fingerprint)
      d20_d = d20_c.map { |li| li.listed_object.fingerprint }
      expect(d20_d).to contain_exactly(d20.fingerprint, d20.fingerprint)
    end

    it 'should remove a destroyed object from all lists' do
      l1 = create(:list, objects: [ d21, d10 ], owner: a1)
      l2 = create(:list, objects: [ d11, d20, d21, d10 ], owner: a2)

      expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21, d10 ]))
      expect(obj_fingerprints(l2.objects)).to eql(obj_fingerprints([ d11, d20, d21, d10 ]))

      d10.destroy
      l1.reload
      l2.reload
      expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21 ]))
      expect(obj_fingerprints(l2.objects)).to eql(obj_fingerprints([ d11, d20, d21 ]))

      d11.destroy
      l1.reload
      l2.reload
      expect(obj_fingerprints(l1.objects)).to eql(obj_fingerprints([ d21 ]))
      expect(obj_fingerprints(l2.objects)).to eql(obj_fingerprints([ d20, d21 ]))
    end
  end

  describe 'list management' do
    context '#lists' do
      it 'should return the correct list' do
        l1 = create(:list, owner: a1, objects: [ [ d10, a1 ], [ d20, a2 ] ])
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

        d10_l = d10.lists.map { |l| l.fingerprint }
        expect(d10_l).to contain_exactly(l1.fingerprint)

        d20_l = d20.lists.map { |l| l.fingerprint }
        expect(d20_l).to contain_exactly(l1.fingerprint, l2.fingerprint)
      end
    end
    
    context '#add_to_list' do
      it 'should add the listable if not already in the list' do
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

        expect(obj_fingerprints(d10.lists)).to eql([ ])
        
        li1 = d10.add_to_list(l2, a1)
        expect(li1).to be_an_instance_of(Fl::Framework::List::ListItem)
        expect(li1.list.fingerprint).to eql(l2.fingerprint)
        expect(li1.listed_object.fingerprint).to eql(d10.fingerprint)
        expect(li1.owner.fingerprint).to eql(a1.fingerprint)
        expect(obj_fingerprints(d10.lists(true))).to contain_exactly(l2.fingerprint)

        li2 = d10.add_to_list(l2)
        expect(li2.fingerprint).to eql(li1.fingerprint)
        expect(obj_fingerprints(d10.lists(true))).to contain_exactly(l2.fingerprint)
      end

      it 'should use the list owner if necessary' do
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])
        
        li = d10.add_to_list(l2)
        expect(li).to be_an_instance_of(Fl::Framework::List::ListItem)
        expect(li.owner.fingerprint).to eql(l2.owner.fingerprint)
      end
    end
    
    context '#remove_from_list' do
      it 'should remove the listable if in the list' do
        l1 = create(:list, owner: a1, objects: [ [ d10, a1 ], [ d20, a2 ] ])
        l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

        expect(d10.remove_from_list(l1)).to eql(true)
        expect(obj_fingerprints(d10.lists(true))).to eql([ ])

        expect(d10.remove_from_list(l2)).to eql(false)
        expect(d10.remove_from_list(l1)).to eql(false)
      end
    end
  end

  describe "item summary management" do
    it "should refresh item summaries after a save" do
      l1 = create(:list, owner: a1, objects: [ [ d10, a1 ], [ d20, a2 ] ])
      l2 = create(:list, owner: a2, objects: [ [ d20, a1 ] ])

      l1_s = l1.list_items.map { |li| li.item_summary }
      expect(l1_s).to match_array([ d10.title, "my title: #{d20.title}" ])
      l2_s = l2.list_items.map { |li| li.item_summary }
      expect(l2_s).to match_array([ "my title: #{d20.title}" ])

      d20_new_title = 'd20 - new title'
      d20.title = d20_new_title
      expect(d20.save).to eql(true)

      l1.list_items.reload
      l1_s = l1.list_items.map { |li| li.item_summary }
      expect(l1_s).to match_array([ d10.title, "my title: #{d20.title}" ])
      l2.list_items.reload
      l2_s = l2.list_items.map { |li| li.item_summary }
      expect(l2_s).to match_array([ "my title: #{d20_new_title}" ])
    end
  end
end
