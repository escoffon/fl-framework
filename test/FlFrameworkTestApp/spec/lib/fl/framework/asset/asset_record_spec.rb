require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe Fl::Framework::Asset::AssetRecord, type: :model do
  let(:a1) { create(:test_actor) }
  let(:a2) { create(:test_actor) }
  let(:a3) { create(:test_actor) }
  let(:d10) { create(:test_datum_one, owner: a1, value: 10) }
  let(:d11) { create(:test_datum_one, owner: a2, value: 11) }
  let(:d12) { create(:test_datum_one, owner: a2, value: 12) }
  let(:d20) { create(:test_datum_two, owner: a1, value: 'v20') }
  let(:d21) { create(:test_datum_two, owner: a2, value: 'v21') }
  let(:d22) { create(:test_datum_two, owner: a1, value: 'v22') }
  let(:d30) { create(:test_datum_three, owner: a2, value: 30) }

  describe '#initialize' do
    it 'should fail with empty attributes' do
      ar1 = Fl::Framework::Asset::AssetRecord.new
      expect(ar1.valid?).to eq(false)
      expect(ar1.errors.messages.keys).to contain_exactly(:owner, :asset)
    end

    it 'should succeed with asset and owner' do
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d11, owner: d11.owner)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d11.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d11.fingerprint)
    end

    it 'should accept fingerprint arguments' do
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d11.fingerprint, owner: d11.owner.fingerprint)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d11.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d11.fingerprint)

      ar2 = Fl::Framework::Asset::AssetRecord.new(asset: d11.fingerprint)
      expect(ar2.valid?).to eq(true)
      expect(ar2.owner.fingerprint).to eql(d11.owner.fingerprint)
      expect(ar2.asset.fingerprint).to eql(d11.fingerprint)
    end

    it 'should use the asset owner if necessary and possible' do
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d11)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d11.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d11.fingerprint)
    end
  end

  describe 'create' do
    it 'should populate the fingerprint attributes on creation' do
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d11)

      expect(ar1.valid?).to eq(true)
      expect(ar1.owner_fingerprint).to be_nil

      expect(ar1.save).to eq(true)
      expect(ar1.owner_fingerprint).to eql(d11.owner.fingerprint)
    end
  end
  
  describe '#update_attributes' do
    it 'should ignore :asset and :owner attributes' do
      ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d11, owner: d11.owner)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d11.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d11.fingerprint)

      ar1.update_attributes(asset: d21, owner: a2)
      expect(ar1.valid?).to eq(true)
      expect(ar1.owner.fingerprint).to eql(d11.owner.fingerprint)
      expect(ar1.asset.fingerprint).to eql(d11.fingerprint)
    end
  end

  describe "model hash support" do
    context "#to_hash" do
      it "should track :verbosity" do
        ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d11, owner: d11.owner)

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
        ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d11, owner: d11.owner)

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
        ar1 = Fl::Framework::Asset::AssetRecord.new(asset: d11, owner: d11.owner)

        id_keys = [ :type, :api_root, :url_path, :fingerprint, :id ]
        h = ar1.to_hash(a1, { verbosity: :minimal })
        a_keys = id_keys + [ :owner, :title, :value, :created_at, :updated_at ]
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
      a10 = Fl::Framework::Asset::AssetRecord.create(asset: d10)
      a11 = Fl::Framework::Asset::AssetRecord.create(asset: d11)
      a12 = Fl::Framework::Asset::AssetRecord.create(asset: d12)
      a20 = Fl::Framework::Asset::AssetRecord.create(asset: d20)
      a21 = Fl::Framework::Asset::AssetRecord.create(asset: d21)
      a22 = Fl::Framework::Asset::AssetRecord.create(asset: d22)
      
      q = Fl::Framework::Asset::AssetRecord.build_query()
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22, d21, d20, d12, d11, d10 ]))
    end

    it 'should process :only_owners and :except_owners' do
      a10 = Fl::Framework::Asset::AssetRecord.create(asset: d10)
      a11 = Fl::Framework::Asset::AssetRecord.create(asset: d11)
      a12 = Fl::Framework::Asset::AssetRecord.create(asset: d12)
      a20 = Fl::Framework::Asset::AssetRecord.create(asset: d20)
      a21 = Fl::Framework::Asset::AssetRecord.create(asset: d21)
      a22 = Fl::Framework::Asset::AssetRecord.create(asset: d22)
      
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
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d21, d12, d11 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(except_owners: [ a1.fingerprint ])
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d21, d12, d11 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(except_owners: a2)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22, d20, d10 ]))

      q = Fl::Framework::Asset::AssetRecord.build_query(except_owners: [ a2 ])
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ d22, d20, d10 ]))
      
      q = Fl::Framework::Asset::AssetRecord.build_query(only_owners: a3.fingerprint)
      ql = q.map { |li| li.asset }
      expect(obj_fingerprints(ql)).to eql(obj_fingerprints([ ]))
    end

    it 'should process :only_asset_types and :except_asset_types' do
      a10 = Fl::Framework::Asset::AssetRecord.create(asset: d10)
      a11 = Fl::Framework::Asset::AssetRecord.create(asset: d11)
      a12 = Fl::Framework::Asset::AssetRecord.create(asset: d12)
      a20 = Fl::Framework::Asset::AssetRecord.create(asset: d20)
      a21 = Fl::Framework::Asset::AssetRecord.create(asset: d21)
      a22 = Fl::Framework::Asset::AssetRecord.create(asset: d22)
      a30 = Fl::Framework::Asset::AssetRecord.create(asset: d30)
      
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
      a10 = Fl::Framework::Asset::AssetRecord.create(asset: d10)
      a11 = Fl::Framework::Asset::AssetRecord.create(asset: d11)
      a12 = Fl::Framework::Asset::AssetRecord.create(asset: d12)
      a20 = Fl::Framework::Asset::AssetRecord.create(asset: d20)
      a21 = Fl::Framework::Asset::AssetRecord.create(asset: d21)
      a22 = Fl::Framework::Asset::AssetRecord.create(asset: d22)
      a30 = Fl::Framework::Asset::AssetRecord.create(asset: d30)
      
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
      a10 = Fl::Framework::Asset::AssetRecord.create(asset: d10)
      a11 = Fl::Framework::Asset::AssetRecord.create(asset: d11)
      a12 = Fl::Framework::Asset::AssetRecord.create(asset: d12)
      a20 = Fl::Framework::Asset::AssetRecord.create(asset: d20)
      a21 = Fl::Framework::Asset::AssetRecord.create(asset: d21)
      a22 = Fl::Framework::Asset::AssetRecord.create(asset: d22)
      a30 = Fl::Framework::Asset::AssetRecord.create(asset: d30)
      
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
