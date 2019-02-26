class CreateFlFrameworkLists < ActiveRecord::Migration[5.2]
  def change
    # The lists in the system
    
    create_table :fl_framework_lists do |t|
      # The title and caption for the list
      t.string		:title
      t.text		:caption

      # The entity that owns the list; typically this is a user, but we define a polymorphic association
      # for flexibility
      t.references	:owner, polymorphic: true

      # Are new items readonly by default
      t.boolean		:default_readonly_state

      # The access level for list items
      #t.integer		:list_access_level

      # Stores the JSON representation of the display preferences for the list
      t.text		:list_display_preferences

      t.timestamps
    end

    # The known states for a list item
    
    create_table :fl_framework_list_item_state_t do |t|
      # Rails needs to convert this into symbols in the runtime
      t.string		:name

      # and this is a backstop value if the translation is not found in Rails
      t.text		:desc_backstop
    end

    # This table associates objects with lists and provides storage for a many-to-many association
    
    create_table :fl_framework_list_items do |t|
      # The list
      t.references	:list, index: { name: :fl_fmwk_l_i_list_idx }

      # The listed object; polymorphic since lists can hold heterogeneous collections
      # The fingerprint is a query optimizer
      t.references	:listed_object, polymorphic: true, index: { name: :fl_fmwk_l_i_lo_idx }
      t.string		:listed_object_fingerprint, index: { name: :fl_fmwk_l_i_lo_fp_idx }

      # We may need an additional class name field in situations when the listed object is an instance of
      # a subclass in a hierarchy of listable objects. (For example, a reminder is a subclass of a calendar
      # item, and the listable extensions are in the latter rather than the former.)
      t.string		:listed_object_class_name, index: { name: :fl_fmwk_l_i_lo_cn_idx }

      # The entity that owns the item; typically this is a user, but we define a polymorphic association
      # for flexibility
      # The fingerprint is a query optimizer
      t.references	:owner, polymorphic: true, index: { name: :fl_fmwk_l_i_own_idx }
      t.string		:owner_fingerprint, index: { name: :fl_fmwk_l_i_own_fp_idx }

      # The name of the list item.
      # Used to identify list items by path; must also be unique for a given list (currently enforced
      # at the ActiveRecord model level)
      t.string	:name

      # Set to `true` if the object's state cannot be modified, `false` if it can
      t.boolean		:readonly_state

      # The state of the relationship:
      # - the state value and a note associated with the update
      # - when it was last set
      # - who set it; polymorphic for flexibility
      t.integer		:state
      t.text		:state_note
      t.datetime	:state_updated_at
      t.references	:state_updated_by, polymorphic: true, index: { name: :fl_fmwk_l_i_state_uby_idx }

      # Sort order
      t.integer		:sort_order

      # This is a denormalization done so that queries can sort by the list item's summary without
      # creating a join
      t.string		:item_summary, index: { name: :fl_fmwk_l_i_summary_idx }

      t.timestamps
    end

    reversible do |o|
      o.up do
        # The current known item states
        execute <<-SQL
          INSERT INTO fl_framework_list_item_state_t (id, name, desc_backstop)
	    VALUES (1, 'selected', 'Selected (Normal)');
        SQL

        execute <<-SQL
          INSERT INTO fl_framework_list_item_state_t (id, name, desc_backstop)
	    VALUES (2, 'deselected', 'Deselected');
        SQL

        # constraints of the list item association table

        execute <<-SQL
          ALTER TABLE fl_framework_list_items
          ADD CONSTRAINT fl_fmwk_list_items_list_fk FOREIGN KEY (list_id) REFERENCES fl_framework_lists(id)
        SQL

        execute <<-SQL
          ALTER TABLE fl_framework_list_items
            ADD CONSTRAINT fl_fmwk_list_items_sta_fk FOREIGN KEY (state) REFERENCES fl_framework_list_item_state_t(id)
        SQL
      end

      o.down do
      end
    end
  end
end
