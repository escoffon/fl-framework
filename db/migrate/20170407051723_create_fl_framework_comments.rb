# Migration to create the comments table for the fl-framework comments engine

class CreateFlFrameworkComments < ActiveRecord::Migration[5.0]
  def change
    create_table :fl_framework_comments do |t|
      t.references :commentable, polymorphic: true, index: { name: 'fl_framework_comments_commentable_ref' }
      t.references :author, polymorphic: true, index: { name: 'fl_framework_comments_author_ref' }
      t.text :title
      t.text :contents

      t.timestamps
    end

    reversible do |o|
      o.up do
      end

      o.down do
      end
    end
  end
end
