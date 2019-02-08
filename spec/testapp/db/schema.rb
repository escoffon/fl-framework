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

ActiveRecord::Schema.define(version: 2019_02_02_222507) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "fl_framework_attachments", id: :serial, force: :cascade do |t|
    t.string "type"
    t.string "attachable_type"
    t.integer "attachable_id"
    t.string "author_type"
    t.integer "author_id"
    t.string "attachment_file_name"
    t.string "attachment_content_type"
    t.integer "attachment_file_size"
    t.datetime "attachment_updated_at"
    t.string "attachment_fingerprint"
    t.text "title"
    t.text "caption"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attachable_type", "attachable_id"], name: "fl_framework_attach_attachable_ref"
    t.index ["author_type", "author_id"], name: "fl_framework_attach_author_ref"
    t.index ["type"], name: "fl_framework_att_type"
  end

  create_table "fl_framework_comments", id: :serial, force: :cascade do |t|
    t.string "commentable_type"
    t.integer "commentable_id"
    t.string "author_type"
    t.integer "author_id"
    t.text "title"
    t.text "contents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "fl_framework_comments_author_ref"
    t.index ["commentable_type", "commentable_id"], name: "fl_framework_comments_commentable_ref"
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
    t.index ["item_summary"], name: "fl_frmk_l_i_summary_idx"
    t.index ["list_id"], name: "index_fl_framework_list_items_on_list_id"
    t.index ["listed_object_class_name"], name: "fl_frmk_l_i_lo_cn_idx"
    t.index ["listed_object_fingerprint"], name: "fl_frmk_l_i_lo_fp_idx"
    t.index ["listed_object_type", "listed_object_id"], name: "fl_frmk_l_i_lo_idx"
    t.index ["owner_fingerprint"], name: "fl_frmk_l_i_own_fp_idx"
    t.index ["owner_type", "owner_id"], name: "fl_frmk_l_i_own_idx"
    t.index ["state_updated_by_type", "state_updated_by_id"], name: "fl_frmk_l_i_state_uby_idx"
  end

  create_table "fl_framework_lists", force: :cascade do |t|
    t.string "title"
    t.text "caption"
    t.string "owner_type"
    t.bigint "owner_id"
    t.boolean "default_readonly_state"
    t.text "list_display_preferences"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_fl_framework_lists_on_owner_type_and_owner_id"
  end

  create_table "test_actors", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  add_foreign_key "fl_framework_list_items", "fl_framework_list_item_state_t", column: "state", name: "fl_frmk_list_items_sta_fk"
  add_foreign_key "fl_framework_list_items", "fl_framework_lists", column: "list_id", name: "fl_frmk_list_items_list_fk"
end
