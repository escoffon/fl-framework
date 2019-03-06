# Tables for managing assets

class CreateFlFrameworkAssets < ActiveRecord::Migration[5.2]
  def change
    # A catalog of assets known to the system
    # (Currently used mostly by access control)
    
    create_table :fl_framework_assets do |t|
      # The entity that owns the asset; typically this is a user, but we define a polymorphic association
      # for flexibility.
      # This reference serves two purposes: data objects that do not store a reference to an owner
      # can do so here. And for those that do, this makes it possible to query and join by owner, which
      # we can't really do since the data reference is also polymorphic.
      # The owner_fingerprint attribute is an optimization for query support
      t.references	:owner, polymorphic: true, index: { name: :fl_fmwk_assets_owner_idx }
      t.string		:owner_fingerprint, index: { name: :fl_fmwk_assets_owner_fp_idx }

      # The entity that owns the asset data; polymorphic because assets map to different model classes.
      t.references	:asset, polymorphic: true, index: { name: :fl_fmwk_assets_asset_idx }

      t.timestamps
    end

    # This index is used to speed up queries based on asset types

    add_index :fl_framework_assets, :asset_type, name: :fl_fmwk_assets_asset_type_idx

    reversible do |o|
      o.up do
      end

      o.down do
      end
    end
  end
end
