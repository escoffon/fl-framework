require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe Fl::Framework::Attachment::ActiveStorage::Base, type: :model do
  describe '.attachment_options' do
    it 'should be defined for all classes with attachments' do
      expect(TestAvatarUser.methods).to include(:attachment_options)
      expect(TestDatumAttachment.methods).to include(:attachment_options)
    end

    it 'should return the correct list of configurations' do
      expect(TestAvatarUser.attachment_options.keys).to match_array([ :avatar ])
      expect(TestDatumAttachment.attachment_options.keys).to match_array([ :image, :plain ])
    end

    it 'should return the expected configurations' do
      cfg = Fl::Framework::Attachment.config
      
      expect(TestAvatarUser.attachment_options(:avatar)).to include(cfg.defaults(:fl_avatar))
      expect(TestDatumAttachment.attachment_options(:image)).to include(cfg.defaults(:fl_image))
      expect(TestDatumAttachment.attachment_options(:plain)).to include(cfg.defaults(:fl_generic_file))
    end
  end

  describe '.attachment_styles' do
    it 'should be defined for all classes with attachments' do
      expect(TestAvatarUser.methods).to include(:attachment_styles)
      expect(TestDatumAttachment.methods).to include(:attachment_styles)
    end

    it 'should return the correct list of styles' do
      expect(TestAvatarUser.attachment_styles.keys).to match_array([ :avatar ])
      expect(TestDatumAttachment.attachment_styles.keys).to match_array([ :image, :plain ])
    end

    it 'should return the expected styles' do
      cfg = Fl::Framework::Attachment.config
      
      expect(TestAvatarUser.attachment_styles(:avatar)).to include(cfg.defaults(:fl_avatar)[:styles])
      expect(TestDatumAttachment.attachment_styles(:image)).to include(cfg.defaults(:fl_image)[:styles])
      expect(TestDatumAttachment.attachment_styles(:plain)).to include(cfg.defaults(:fl_generic_file)[:styles])
    end
  end

  describe '.attachment_style' do
    it 'should be defined for all classes with attachments' do
      expect(TestAvatarUser.methods).to include(:attachment_style)
      expect(TestDatumAttachment.methods).to include(:attachment_style)
    end

    it 'should return the expected style' do
      cfg = Fl::Framework::Attachment.config

      s = cfg.defaults(:fl_avatar)[:styles]
      expect(TestAvatarUser.attachment_style(:avatar, :thumb)).to include(s[:thumb])
      expect(TestAvatarUser.attachment_style(:avatar, :unknown)).to be_a(Hash)
      expect(TestAvatarUser.attachment_style(:avatar, :unknown).count).to eql(0)

      s = cfg.defaults(:fl_image)[:styles]
      expect(TestDatumAttachment.attachment_style(:image, :small)).to include(s[:small])
      expect(TestDatumAttachment.attachment_style(:image, :unknown)).to be_a(Hash)
      expect(TestDatumAttachment.attachment_style(:image, :unknown).count).to eql(0)

      s = cfg.defaults(:fl_generic_file)[:styles]
      expect(TestDatumAttachment.attachment_style(:plain, :original)).to include(s[:original])
    end
  end
end
