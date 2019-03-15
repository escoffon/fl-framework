# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_03_07_175045) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "fl_framework_access_grants", force: :cascade do |t|
    t.string "permission"
    t.bigint "asset_id"
    t.string "data_object_type"
    t.bigint "data_object_id"
    t.string "data_object_fingerprint"
    t.string "actor_type"
    t.bigint "actor_id"
    t.string "actor_fingerprint"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_fingerprint"], name: "fl_fmwk_acl_grants_fp_idx"
    t.index ["actor_type", "actor_id"], name: "fl_fmwk_acl_grants_actor_idx"
    t.index ["asset_id"], name: "fl_fmwk_acl_grants_asset_idx"
    t.index ["data_object_fingerprint"], name: "fl_fmwk_acl_grants_data_fp_idx"
    t.index ["data_object_type", "data_object_id"], name: "fl_fmwk_acl_grants_data_idx"
    t.index ["data_object_type"], name: "fl_fmwk_acl_grants_data_type_idx"
    t.index ["permission"], name: "fl_fmwk_acl_grants_perm_idx"
  end

  create_table "fl_framework_assets", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "owner_fingerprint"
    t.string "asset_type"
    t.bigint "asset_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_type", "asset_id"], name: "fl_fmwk_assets_asset_idx", unique: true
    t.index ["asset_type"], name: "fl_fmwk_assets_asset_type_idx"
    t.index ["owner_fingerprint"], name: "fl_fmwk_assets_owner_fp_idx"
    t.index ["owner_type", "owner_id"], name: "fl_fmwk_assets_owner_idx"
  end

  create_table "fl_framework_list_item_state_t", force: :cascade do |t|
    t.string "name"
    t.text "desc_backstop"
  end

  create_table "fl_framework_list_items", force: :cascade do |t|
    t.bigint "list_id"
    t.string "listed_object_type"
    t.bigint "listed_object_id"
    t.string "listed_object_fingerprint"
    t.string "listed_object_class_name"
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "owner_fingerprint"
    t.string "name"
    t.boolean "readonly_state"
    t.integer "state"
    t.text "state_note"
    t.datetime "state_updated_at"
    t.string "state_updated_by_type"
    t.bigint "state_updated_by_id"
    t.integer "sort_order"
    t.string "item_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_summary"], name: "fl_fmwk_l_i_summary_idx"
    t.index ["list_id"], name: "fl_fmwk_l_i_list_idx"
    t.index ["listed_object_class_name"], name: "fl_fmwk_l_i_lo_cn_idx"
    t.index ["listed_object_fingerprint"], name: "fl_fmwk_l_i_lo_fp_idx"
    t.index ["listed_object_type", "listed_object_id"], name: "fl_fmwk_l_i_lo_idx"
    t.index ["owner_fingerprint"], name: "fl_fmwk_l_i_own_fp_idx"
    t.index ["owner_type", "owner_id"], name: "fl_fmwk_l_i_own_idx"
    t.index ["state_updated_by_type", "state_updated_by_id"], name: "fl_fmwk_l_i_state_uby_idx"
  end

  create_table "fl_framework_lists", force: :cascade do |t|
    t.string "title"
    t.text "caption"
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "owner_fingerprint"
    t.boolean "default_readonly_state"
    t.text "list_display_preferences"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_fingerprint"], name: "fl_fmwk_list_owner_fp_idx"
    t.index ["owner_type", "owner_id"], name: "fl_fmwk_list_owner_idx"
  end

  create_table "test_actors", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "test_datum_fours", force: :cascade do |t|
    t.string "title"
    t.bigint "owner_id"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_test_datum_fours_on_owner_id"
  end

  create_table "test_datum_ones", force: :cascade do |t|
    t.string "title"
    t.bigint "owner_id"
    t.integer "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_test_datum_ones_on_owner_id"
  end

  create_table "test_datum_threes", force: :cascade do |t|
    t.string "title"
    t.bigint "owner_id"
    t.integer "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_test_datum_threes_on_owner_id"
  end

  create_table "test_datum_twos", force: :cascade do |t|
    t.string "title"
    t.bigint "owner_id"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_test_datum_twos_on_owner_id"
  end

  add_foreign_key "fl_framework_access_grants", "fl_framework_assets", column: "asset_id", name: "fl_fmwk_acl_grants_asset_fk"
  add_foreign_key "fl_framework_list_items", "fl_framework_list_item_state_t", column: "state", name: "fl_fmwk_list_items_sta_fk"
  add_foreign_key "fl_framework_list_items", "fl_framework_lists", column: "list_id", name: "fl_fmwk_list_items_list_fk"
end
