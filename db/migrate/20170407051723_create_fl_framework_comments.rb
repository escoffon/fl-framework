# Migration to create the comments table for the fl-framework comments engine

class CreateFlFrameworkComments < ActiveRecord::Migration[5.0]
  def change
    create_table :fl_framework_comments do |t|
      # Polymorphic reference to the commentable (object to which the comment is attach)
      t.references :commentable, polymorphic: true, index: { name: 'fl_framework_comments_commentable_ref' }

      # Polymorphic reference to the comment's author (and therefore owner)
      t.references :author, polymorphic: true, index: { name: 'fl_framework_comments_author_ref' }

      # Comment properties
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
