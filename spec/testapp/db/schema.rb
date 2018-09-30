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

ActiveRecord::Schema.define(version: 2017_04_19_011540) do

  create_table "fl_framework_attachments", force: :cascade do |t|
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

  create_table "fl_framework_comments", force: :cascade do |t|
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

  create_table "test_actors", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "test_datum_ones", force: :cascade do |t|
    t.string "title"
    t.integer "owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_test_datum_ones_on_owner_id"
  end

end
