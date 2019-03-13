require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe Fl::Framework::Asset::Helper, type: :model do
  let(:a1) { create(:test_actor, name: 'actor.1') }
  let(:a2) { create(:test_actor, name: 'actor.2') }
  let(:d10) { build(:test_datum_one, value: 10, owner: a1) }
  let(:d20) { build(:test_datum_two, value: 'v20', owner: a1) }
  let(:d40) { build(:test_datum_four, value: 'v40', owner: a2) }

  describe '.make_asset' do
    it 'should turn on asset supprt' do
      expect(TestDatumFour.methods).to include(:asset?)
      expect(TestDatumFour.instance_methods).to include(:asset?)

      d41 = build(:test_datum_four, value: 'v41', owner: a2)
      expect(d41.asset?).to eql(false)
      expect do
        d41.save
      end.not_to change(Fl::Framework::Asset::AssetRecord, :count)

      Fl::Framework::Asset::Helper.make_asset(TestDatumFour)

      expect(TestDatumFour.methods).to include(:is_asset)

      d42 = build(:test_datum_four, value: 'v42', owner: a2)
      expect(d42.asset?).to eql(true)
      expect do
        d42.save
      end.to change(Fl::Framework::Asset::AssetRecord, :count).by(1)
      expect(d42.asset_record).to be_a(Fl::Framework::Asset::AssetRecord)
      expect(d42.asset_record.asset.fingerprint).to eql(d42.fingerprint)
    end
  end
end
