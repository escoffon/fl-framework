# This migration comes from fl_framework (originally 20170414184953)
class CreateFlFrameworkAttachments < ActiveRecord::Migration[5.0]
  def change
    create_table :fl_framework_attachments do |t|
      # STI support
      t.string :type, index: { name: 'fl_framework_att_type' }

      # Polymorphic reference to the attachable (master object)
      t.references :attachable, polymorphic: true, index: { name: 'fl_framework_attach_attachable_ref' }

      # Polymorphic reference to the author (the entity that created the attachment)
      t.references :author, polymorphic: true, index: { name: 'fl_framework_attach_author_ref' }

      # Paperclip attributes
      t.attachment :attachment
      t.string :attachment_fingerprint

      # Attachment attributes
      t.text :title
      t.text :caption

      t.timestamps
    end
  end
end
