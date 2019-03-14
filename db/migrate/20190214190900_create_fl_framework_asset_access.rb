# Tables for managing asset access control

class CreateFlFrameworkAssetAccess < ActiveRecord::Migration[5.2]
  def change
    # The permission grants in the system

    create_table :fl_framework_access_grants do |t|
      # The name of the permission
      t.string		:permission, index: { name: :fl_fmwk_acl_grants_perm_idx }

      # The asset that is granting the permission
      t.references	:asset, index: { name: :fl_fmwk_acl_grants_asset_idx }

      # The object that contains the actual asset data
      # This denormalization is used for performance reasons, to avoid a join with the assets table
      # when filtering by asset type.
      # (And also to get the data object directly, rather than through the assets table.)
      # The data_object_fingerprint attribute is an optimization for query support
      t.references	:data_object, polymorphic: true, index: { name: :fl_fmwk_acl_grants_data_idx }
      t.string		:data_object_fingerprint, index: { name: :fl_fmwk_acl_grants_data_fp_idx }

      # The actor to which permission is granted
      # The actor_fingerprint attribute is an optimization for query support
      t.references	:actor, polymorphic: true, index: { name: :fl_fmwk_acl_grants_actor_idx }
      t.string		:actor_fingerprint, index: { name: :fl_fmwk_acl_grants_fp_idx }

      # Only the created_at column is meaningful, since grant records are not updated
      t.timestamps
    end

    # This index optimizes data type filters
    add_index :fl_framework_access_grants, :data_object_type, name: :fl_fmwk_acl_grants_data_type_idx
    
    reversible do |o|
      o.up do
        # constraints on the access grants table

        execute <<-SQL
          ALTER TABLE fl_framework_access_grants
          ADD CONSTRAINT fl_fmwk_acl_grants_asset_fk FOREIGN KEY (asset_id) REFERENCES fl_framework_assets(id)
        SQL
      end

      o.down do
      end
    end
  end
end
