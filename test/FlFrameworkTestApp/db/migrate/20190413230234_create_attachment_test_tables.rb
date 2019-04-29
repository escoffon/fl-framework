class CreateAttachmentTestTables < ActiveRecord::Migration[5.2]
  def change
    # A user object that will have an avatar attachment.
    
    create_table :test_avatar_users do |t|
      t.string		:name

      t.timestamps
    end

    # A data object that will have two attachments.
    
    create_table :test_datum_attachments do |t|
      t.string		:title
      t.references	:owner
      t.string		:value

      t.timestamps
    end
  end
end
