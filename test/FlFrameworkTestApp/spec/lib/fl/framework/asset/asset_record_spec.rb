require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

# Testing creation is tricky, since asset objects automatically create an asset_record from an
# after_create hook, so we have to resort to somewhat unothodox methods

module T
  def self.clear_asset_record(d)
    ar = Fl::Framework::Asset::AssetRecord.where('(asset_type = :at) AND (asset_id = :aid)',
                                                 at: d.class.name, aid: d.id).first
    ar.destroy if ar
  end
end

RSpec.describe Fl::Framework::Asset::AssetRecord, type: :model do
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
  
  describe '#initialize' do
    it 'should fail with empty attributes' do
      ar1 = Fl::Framework::Asset::AssetRecord.new
      expect(ar1.valid?).to eq(false)
      expect(ar1.errors.messages.keys).to contain_exactly(:owner, :asset)
    end

    it 'should succeed with asset and owner' do
      T.clear_asset_record(d110)
      
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d110, owner: d110.owner)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d110.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d110.fingerprint)
    end

    it 'should accept fingerprint arguments' do
      T.clear_asset_record(d110)
      
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d110.fingerprint, owner: d110.owner.fingerprint)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d110.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d110.fingerprint)

      ar2 = Fl::Framework::Asset::AssetRecord.new(asset: d110.fingerprint)
      expect(ar2.valid?).to eq(true)
      expect(ar2.owner.fingerprint).to eql(d110.owner.fingerprint)
      expect(ar2.asset.fingerprint).to eql(d110.fingerprint)
    end

    it 'should use the asset owner if necessary and possible' do
      T.clear_asset_record(d110)
      
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d110)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d110.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d110.fingerprint)
    end
  end

  describe 'create' do
    it 'should populate the fingerprint attributes on creation' do
      T.clear_asset_record(d110)
      
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d110)

      expect(ar1.valid?).to eq(true)
      expect(ar1.owner_fingerprint).to be_nil

      expect(ar1.save).to eq(true)
      expect(ar1.owner_fingerprint).to eql(d110.owner.fingerprint)
    end
  end

  describe 'validate' do
    it 'should fail if the asset is not a registered asset' do
      d40 = create(:test_datum_four, owner: a1)
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d40)

      expect(ar1.valid?).to eq(false)
      expect(ar1.errors.messages.keys).to include(:asset)
    end

    it 'should fail if an asset record exists for the same asset' do
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d10)

      expect(ar1.valid?).to eq(false)
      expect(ar1.errors.messages.keys).to include(:asset)
    end
  end
  
  describe '#update_attributes' do
    it 'should ignore :asset and :owner attributes' do
      T.clear_asset_record(d110)
      T.clear_asset_record(d21)
      
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d110, owner: d110.owner)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d110.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d110.fingerprint)

      ar1.update_attributes(asset: d21, owner: a2)
      T.clear_asset_record(d110)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d110.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d110.fingerprint)
    end
  end

  describe "model hash support" do
    context "#to_hash" do
      it "should track :verbosity" do
        T.clear_asset_record(d110)
      
        ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d110, owner: d110.owner)

        id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
        h = ar1.to_hash(a1, { verbosity: :id })
        expect(h.keys).to match_array(id_keys)

        ignore_keys = id_keys | [ ]
        h = ar1.to_hash(a1, { verbosity: :ignore })
        expect(h.keys).to match_array(ignore_keys)

        minimal_keys = id_keys | [ :asset, :owner, :created_at, :updated_at ]
        h = ar1.to_hash(a1, { verbosity: :minimal })
        expect(h.keys).to match_array(minimal_keys)

        standard_keys = minimal_keys | [ ]
        h = ar1.to_hash(a1, { verbosity: :standard })
        expect(h.keys).to match_array(standard_keys)

        verbose_keys = standard_keys | [ ]
        h = ar1.to_hash(a1, { verbosity: :verbose })
        expect(h.keys).to match_array(verbose_keys)

        complete_keys = verbose_keys | [ ]
        h = ar1.to_hash(a1, { verbosity: :complete })
        expect(h.keys).to match_array(complete_keys)
      end

      it "should customize key lists" do
        T.clear_asset_record(d110)
      
        ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d110, owner: d110.owner)

        id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
        h_keys = id_keys | [ :asset ]
        h = ar1.to_hash(a1, { verbosity: :id, include: [ :asset ] })
        expect(h.keys).to match_array(h_keys)

        minimal_keys = id_keys | [ :asset, :owner, :created_at, :updated_at ]
        h_keys = minimal_keys - [ :asset ]
        h = ar1.to_hash(a1, { verbosity: :minimal, except: [ :asset ] })
        expect(h.keys).to match_array(h_keys)
      end

      it "should customize key lists for subobjects" do
        T.clear_asset_record(d110)
      
        ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d110, owner: d110.owner)

        id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
        h = ar1.to_hash(a1, { verbosity: :minimal })
        a_keys = id_keys + [ :owner, :title, :value, :permissions, :created_at, :updated_at ]
        expect(h[:asset].keys).to match_array(a_keys)

        h = ar1.to_hash(a1, {
                          verbosity: :minimal,
                          to_hash: {
                            owner: { verbosity: :id },
                            asset: { verbosity: :id, include: :title }
                          }
                        })
        a_keys = id_keys + [ :title ]
        expect(h[:asset].keys).to match_array(a_keys)
        o_keys = id_keys + [ ]
        expect(h[:owner].keys).to match_array(o_keys)
      end
    end
  end

  describe ".build_query" do
    it 'should generate a simple query from default options' do
      # This statement implicitly creates the asset records
      data = [ d10, d11, d12, d20, d21, d22 ]

      q = Fl::Framework::Asset::AssetRecord.build_query()
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22, d21, d20, d12, d11, d10 ]))
    end

    it 'should process :only_owners and :except_owners' do
      # This statement implicitly creates the asset records
      data = [ d10, d11, d12, d20, d21, d22, d30 ]
      
      q = Fl::Framework::Asset::AssetRecord.build_query(only_owners: a1.fingerprint)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22, d20, d10 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(only_owners: [ a1.fingerprint ])
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22, d20, d10 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(only_owners: a2)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d21, d12, d11 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(only_owners: [ a2 ])
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d21, d12, d11 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(except_owners: a1.fingerprint)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d30, d21, d12, d11 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(except_owners: [ a1.fingerprint ])
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d30, d21, d12, d11 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(except_owners: a2)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d30, d22, d20, d10 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(except_owners: [ a2 ])
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d30, d22, d20, d10 ]))
      
      q = Fl::Framework::Asset::AssetRecord.build_query(only_owners: a4.fingerprint)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))
    end

    it 'should process :only_asset_types and :except_asset_types' do
      # This statement implicitly creates the asset records
      data = [ d10, d11, d12, d20, d21, d22, d30 ]
      
      q = Fl::Framework::Asset::AssetRecord.build_query(only_asset_types: TestDatumOne)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d12, d11, d10 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(only_asset_types: TestDatumOne.name)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d12, d11, d10 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(only_asset_types: [ TestDatumOne, TestDatumTwo.name ])
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22, d21, d20, d12, d11, d10 ]))
      
      q = Fl::Framework::Asset::AssetRecord.build_query(except_asset_types: TestDatumTwo)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d30, d12, d11, d10 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(except_asset_types: TestDatumTwo.name)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d30, d12, d11, d10 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(except_asset_types: [ TestDatumOne, TestDatumTwo.name ])
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d30 ]))
    end

    it 'should filter by combination of owner and asset type' do
      # This statement implicitly creates the asset records
      data = [ d10, d11, d12, d20, d21, d22, d30 ]
      
      q = Fl::Framework::Asset::AssetRecord.build_query(only_asset_types: TestDatumOne,
                                                        only_owners: a1)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d10 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(only_asset_types: TestDatumOne.name,
                                                        only_owners: a2)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d12, d11 ]))
    end

    it 'should process :order, :offset, :limit' do
      # This statement implicitly creates the asset records
      data = [ d10, d11, d12, d20, d21, d22, d30 ]
      
      q = Fl::Framework::Asset::AssetRecord.build_query(order: 'updated_at ASC', limit: 2, offset: 2)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d12, d20 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(only_asset_types: [ TestDatumOne, TestDatumTwo ],
                                                        limit: 4, offset: 1)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d21, d20, d12, d11 ]))
    end
  end
end
