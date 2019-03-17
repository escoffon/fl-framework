require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe Fl::Framework::Asset::Asset, type: :model do
  let(:a1) { create(:test_actor, name: 'actor.1') }
  let(:a2) { create(:test_actor, name: 'actor.2') }
  let(:d10) { build(:test_datum_one, value: 10, owner: a1) }
  let(:d20) { build(:test_datum_two, value: 'v20', owner: a1) }
  let(:d40) { build(:test_datum_four, value: 'v40', owner: a1) }

  describe '#is_asset' do
    it 'should register asset methods' do
      expect(TestActor.methods).to include(:asset?)
      expect(TestActor.instance_methods).to include(:asset?)
      expect(TestDatumOne.methods).to include(:is_asset, :asset?)
      expect(TestDatumOne.instance_methods).to include(:asset?)
      expect(TestDatumFour.methods).to include(:asset?)
      expect(TestDatumFour.instance_methods).to include(:asset?)

      expect(d10.asset?).to eql(true)
      expect(d20.asset?).to eql(true)
      expect(d40.asset?).to eql(false)

      expect(TestActor.asset?).to eql(false)
      expect(TestDatumOne.asset?).to eql(true)
      expect(TestDatumTwo.asset?).to eql(true)
      expect(TestDatumFour.asset?).to eql(false)
    end

    it 'should register a hook to create the asset record' do
      d = nil
      
      expect do
        d = create(:test_datum_one, value: 100, owner: a1)
      end.to change(Fl::Framework::Asset::AssetRecord, :count).by(1)
      expect(d.asset_record).to be_a(Fl::Framework::Asset::AssetRecord)
      expect(d.asset_record.asset.fingerprint).to eql(d.fingerprint)
    end

    it 'should ensure that the asset record is destroyed on destroy' do
      d = create(:test_datum_one, value: 100, owner: a1)
      
      expect(d.asset_record).to be_a(Fl::Framework::Asset::AssetRecord)
      expect(d.asset_record.asset.fingerprint).to eql(d.fingerprint)

      expect do
        d.destroy
      end.to change(Fl::Framework::Asset::AssetRecord, :count).by(-1)
    end
  end
end
