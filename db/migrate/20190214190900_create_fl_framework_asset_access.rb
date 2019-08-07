# Tables for managing asset access control

class CreateFlFrameworkAssetAccess < ActiveRecord::Migration[5.2]
  def change
    # The permission grants in the system

    create_table :fl_framework_access_grants do |t|
      # Permission bitmask
      t.integer		:grants, index: { name: :fl_fmwk_acl_grants_perm_idx }

      # The target of the grant.
      # The target_fingerprint attribute is an optimization for query support
      t.references	:target, polymorphic: true, index: { name: :fl_fmwk_acl_grants_target_idx }
      t.string		:target_fingerprint, index: { name: :fl_fmwk_acl_grants_target_fp_idx }

      # The actor to which permission is granted
      # The granted_to_fingerprint attribute is an optimization for query support
      t.references	:granted_to, polymorphic: true, index: { name: :fl_fmwk_acl_grants_g_to_idx }
      t.string		:granted_to_fingerprint, index: { name: :fl_fmwk_acl_g_to_fp_idx }

      t.timestamps
    end

    # This index optimizes data type filters
    add_index :fl_framework_access_grants, :target_type, name: :fl_fmwk_acl_grants_target_type_idx
    
    reversible do |o|
      o.up do
      end

      o.down do
      end
    end
  end
end
